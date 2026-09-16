import Benchmark
import Foundation
import JSONSchema

/// Benchmark suite for JSONSchema schema construction, validation, and
/// validation-output rendering hot paths.
///
/// Run with:
///
///     cd Benchmarks
///     swift package --allow-writing-to-package-directory benchmark --target JSONSchemaBenchmarks
///
/// The committed corpus runs offline. Pinned upstream schemas are included
/// when fetched before building; CI requires the complete downloaded corpus.
nonisolated(unsafe) let benchmarks = {
  let regressionThresholds: [BenchmarkMetric: BenchmarkThresholds] = [
    .wallClock: .init(relative: [.p90: 10.0]),
    .cpuTotal: .init(relative: [.p90: 10.0]),
    .mallocCountTotal: .init(relative: [.p90: 10.0], absolute: [.p90: 10]),
  ]

  Benchmark.defaultConfiguration = .init(
    metrics: [.wallClock, .cpuTotal, .mallocCountTotal],
    warmupIterations: 2,
    maxDuration: .seconds(1),
    maxIterations: 500,
    thresholds: regressionThresholds
  )

  let corpus = SchemaCorpus.load()
  let outputConfigurations: [(name: String, configuration: ValidationOutputConfiguration)] = [
    ("flag", .flag),
    ("basic", .basic),
    ("detailed", .detailed),
    ("verbose", .verbose),
  ]

  for sample in corpus.samples {
    Benchmark("construct.\(sample.name).Schema.init", configuration: sample.configuration) {
      benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(try sample.makeSchema())
      }
    }

    for instance in sample.instances {
      // The runner spawns a process per case. Verify only the selected workload
      // in its unmeasured setup, not the entire scaled corpus in every process.
      let schema = try! sample.makeSchema()
      let name = instance.name.isEmpty ? sample.name : "\(sample.name).\(instance.name)"
      let preflight: Benchmark.BenchmarkSetupHook = {
        try instance.verify(schema: schema, name: name)
      }

      Benchmark(
        "validate.\(name).Schema.validate",
        configuration: sample.configuration,
        closure: { benchmark in
          for _ in benchmark.scaledIterations {
            blackHole(schema.validate(instance.value))
          }
        },
        setup: preflight
      )

      for output in outputConfigurations
      where instance.outputLevels.contains(output.configuration.level) {
        Benchmark(
          "output.\(name).\(output.name)",
          configuration: sample.configuration,
          closure: { benchmark in
            for _ in benchmark.scaledIterations {
              blackHole(try schema.validate(instance.value, output: output.configuration))
            }
          },
          setup: preflight
        )
      }
    }
  }
}

struct SchemaCorpus: Sendable {
  let samples: [Sample]

  struct Sample: Sendable {
    let name: String
    let schemaSource: SchemaSource
    let instances: [Instance]
    var isRealWorld = false

    var configuration: Benchmark.Configuration {
      var configuration = Benchmark.defaultConfiguration
      if isRealWorld {
        configuration.warmupIterations = 1
        configuration.maxIterations = 20
        configuration.timeUnits = .microseconds
      }
      return configuration
    }

    func makeSchema() throws -> Schema {
      switch schemaSource {
      case .resource(let schema):
        try Schema(
          rawSchema: schema,
          context: .init(dialect: .draft2020_12)
        )
      case .draft202012MetaSchema:
        try Dialect.draft2020_12.loadMetaSchema()
      case .downloaded(let schema, let baseURI, let remotes):
        try Schema(
          rawSchema: schema,
          context: .init(dialect: .draft2020_12, remoteSchema: remotes),
          baseURI: baseURI
        )
      }
    }
  }

  enum SchemaSource: Sendable {
    case resource(JSONValue)
    case draft202012MetaSchema
    case downloaded(JSONValue, baseURI: URL, remotes: [String: JSONValue])
  }

  struct Instance: Sendable {
    let name: String
    let value: JSONValue
    let expectedValidity: Bool
    let expectedErrors: [ExpectedError]
    var outputLevels: [ValidationOutputLevel] = [.flag, .basic, .detailed, .verbose]
    var minimumLeafErrors = 0

    func verify(schema: Schema, name: String) throws {
      precondition(
        expectedValidity == expectedErrors.isEmpty,
        "\(name): missing error expectations"
      )
      let result = schema.validate(value)
      precondition(result.isValid == expectedValidity, "\(name): unexpected validation result")
      let errors = flattened(result.errors ?? [])
      precondition(
        errors.filter { $0.errors?.isEmpty ?? true }.count >= minimumLeafErrors,
        "\(name): insufficient leaf errors"
      )
      let expectedLeaves = expectedErrors.map { expected in
        guard
          let error = errors.first(where: {
            $0.keyword == expected.keyword
              && $0.instanceLocation.jsonPointerString == expected.instanceLocation
              && ($0.errors?.isEmpty ?? true)
              && !$0.message.isEmpty
          })
        else {
          fatalError("\(name): missing \(expected.keyword) error at \(expected.instanceLocation)")
        }
        return error
      }

      for level in [
        ValidationOutputLevel.flag, .basic, .detailed, .verbose,
      ] {
        let output = try schema.validate(value, output: .init(level: level))
        if level == .flag {
          precondition(output == .boolean(expectedValidity), "\(name): incorrect flag output")
        } else {
          precondition(
            output.object?["valid"] == .boolean(expectedValidity),
            "\(name): incorrect \(level) validity"
          )
          precondition(
            renderedErrorCount(output) >= minimumLeafErrors,
            "\(name): \(level) lost leaf errors"
          )
          for error in expectedLeaves {
            precondition(
              containsRenderedError(output, matching: error),
              "\(name): \(level) lost \(error.keyword) error at \(error.instanceLocation)"
            )
          }
        }
      }
    }

    private func flattened(_ errors: [ValidationError]) -> [ValidationError] {
      errors.flatMap { [$0] + flattened($0.errors ?? []) }
    }

    private func containsRenderedError(_ output: JSONValue, matching error: ValidationError) -> Bool
    {
      if output.object?["valid"] == .boolean(false),
        output.object?["instanceLocation"] == .string(error.instanceLocation.jsonPointerString),
        output.object?["keywordLocation"] == .string(error.keywordLocation.jsonPointerString),
        let message = output.object?["error"]?.string, !message.isEmpty
      {
        return true
      }

      return (output.object?["errors"]?.array ?? [])
        .contains {
          containsRenderedError($0, matching: error)
        }
    }

    private func renderedErrorCount(_ output: JSONValue) -> Int {
      let local = output.object?["error"]?.string?.isEmpty == false ? 1 : 0
      return local
        + (output.object?["errors"]?.array ?? [])
        .reduce(0) {
          $0 + renderedErrorCount($1)
        }
    }
  }

  struct ExpectedError: Sendable {
    let keyword: String
    let instanceLocation: String
  }

  static func load() -> SchemaCorpus {
    let workloads: [(name: String, preservesValidName: Bool, errors: [ExpectedError])] = [
      (
        "poll", true,
        [
          .init(keyword: "minimum", instanceLocation: "/id"),
          .init(keyword: "minLength", instanceLocation: "/options/0/text"),
        ]
      ),
      (
        "openapi-fragment", true,
        [
          .init(keyword: "pattern", instanceLocation: "/openapi"),
          .init(keyword: "required", instanceLocation: "/paths/~1polls/get/responses/200"),
        ]
      ),
      (
        "draft2020-12-schema", true,
        [
          .init(keyword: "type", instanceLocation: "/properties/name/minLength")
        ]
      ),
      (
        "regex-heavy", false,
        [
          .init(keyword: "pattern", instanceLocation: "/tag_01"),
          .init(keyword: "pattern", instanceLocation: "/metric_cpu"),
        ]
      ),
      (
        "reference-heavy", false,
        [
          .init(keyword: "minimum", instanceLocation: "/children/0/id"),
          .init(keyword: "pattern", instanceLocation: "/children/1/children/0/label"),
        ]
      ),
      (
        "combinator-heavy", false,
        [
          .init(keyword: "oneOf", instanceLocation: "/choices/0"),
          .init(keyword: "type", instanceLocation: "/choices/1"),
          .init(keyword: "pattern", instanceLocation: "/id"),
          .init(keyword: "minLength", instanceLocation: "/label"),
        ]
      ),
    ]

    let samples = workloads.map { workload in
      let name = workload.name
      return Sample(
        name: name,
        schemaSource: name == "draft2020-12-schema"
          ? .draft202012MetaSchema : .resource(loadJSONValue(named: "\(name).schema")),
        instances: [
          Instance(
            name: workload.preservesValidName ? "" : "valid",
            value: loadJSONValue(named: "\(name).instance"),
            expectedValidity: true,
            expectedErrors: []
          ),
          Instance(
            name: "invalid",
            value: loadJSONValue(named: "\(name).invalid.instance"),
            expectedValidity: false,
            expectedErrors: workload.errors
          ),
        ]
      )
    }
    let enumSamples = [8, 128].map { count in
      let values = (0..<count).map { JSONValue.string("option-\($0)") }
      return Sample(
        name: "enum-\(count)",
        schemaSource: .resource(["enum": .array(values)]),
        instances: [
          Instance(
            name: "first", value: values[0], expectedValidity: true,
            expectedErrors: [], outputLevels: []
          ),
          Instance(
            name: "last", value: values[count - 1], expectedValidity: true,
            expectedErrors: [], outputLevels: []
          ),
          Instance(
            name: "invalid", value: "unknown", expectedValidity: false,
            expectedErrors: [.init(keyword: "enum", instanceLocation: "")], outputLevels: []
          ),
        ]
      )
    }
    return SchemaCorpus(samples: samples + enumSamples + RealWorldCorpus.load())
  }

  static func loadJSONValue(named resourceName: String) -> JSONValue {
    let bundle = Bundle.module
    guard let url = bundle.url(forResource: resourceName, withExtension: "json", subdirectory: nil)
    else {
      fatalError(
        "Could not locate \(resourceName).json in the JSONSchema benchmark resource bundle."
      )
    }
    do {
      return try JSONValue.parse(Data(contentsOf: url))
    } catch {
      fatalError("Failed to load \(resourceName).json: \(error)")
    }
  }
}
