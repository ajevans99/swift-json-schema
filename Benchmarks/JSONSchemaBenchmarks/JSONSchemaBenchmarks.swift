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
/// The corpus is committed to the repo so CI and local runs exercise the same
/// representative schemas without network downloads.
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
    Benchmark("construct.\(sample.name).Schema.init") { benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(try sample.makeSchema())
      }
    }

    for instance in sample.instances {
      // Each workload gets its own warmed schema so reference caches are not
      // seeded by a different instance. Preflight also checks rendered errors.
      let schema = try! sample.makeSchema()
      let name = instance.name.isEmpty ? sample.name : "\(sample.name).\(instance.name)"
      do {
        try instance.verify(schema: schema, name: name)
      } catch {
        fatalError("Benchmark preflight failed for \(name): \(error)")
      }

      Benchmark("validate.\(name).Schema.validate") { benchmark in
        for _ in benchmark.scaledIterations {
          blackHole(schema.validate(instance.value))
        }
      }

      for output in outputConfigurations {
        Benchmark("output.\(name).\(output.name)") { benchmark in
          for _ in benchmark.scaledIterations {
            blackHole(try schema.validate(instance.value, output: output.configuration))
          }
        }
      }
    }
  }
}

private struct SchemaCorpus: Sendable {
  let samples: [Sample]

  struct Sample: Sendable {
    let name: String
    let schemaSource: SchemaSource
    let instances: [Instance]

    func makeSchema() throws -> Schema {
      switch schemaSource {
      case .resource(let schema):
        try Schema(
          rawSchema: schema,
          context: .init(dialect: .draft2020_12)
        )
      case .draft202012MetaSchema:
        try Dialect.draft2020_12.loadMetaSchema()
      }
    }
  }

  enum SchemaSource: Sendable {
    case resource(JSONValue)
    case draft202012MetaSchema
  }

  struct Instance: Sendable {
    let name: String
    let value: JSONValue
    let expectedValidity: Bool
    let expectedErrors: [ExpectedError]

    func verify(schema: Schema, name: String) throws {
      precondition(
        expectedValidity == expectedErrors.isEmpty,
        "\(name): missing error expectations"
      )
      let result = schema.validate(value)
      precondition(result.isValid == expectedValidity, "\(name): unexpected validation result")
      let errors = flattened(result.errors ?? [])
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

    return SchemaCorpus(
      samples: workloads.map { workload in
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
    )
  }

  private static func loadJSONValue(named resourceName: String) -> JSONValue {
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
