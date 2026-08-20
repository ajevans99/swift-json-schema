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

    let schema = try! sample.makeSchema()
    precondition(
      schema.validate(sample.instance).isValid,
      "Benchmark instance for \(sample.name) must fully validate."
    )

    Benchmark("validate.\(sample.name).Schema.validate") { benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(schema.validate(sample.instance))
      }
    }

    for output in outputConfigurations {
      Benchmark("output.\(sample.name).\(output.name)") { benchmark in
        for _ in benchmark.scaledIterations {
          blackHole(try schema.validate(sample.instance, output: output.configuration))
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
    let instance: JSONValue

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

  static func load() -> SchemaCorpus {
    let resourceNames = [
      "poll", "openapi-fragment",
    ]
    let resourceSamples = resourceNames.map { name in
      Sample(
        name: name,
        schemaSource: .resource(loadJSONValue(named: "\(name).schema")),
        instance: loadJSONValue(named: "\(name).instance")
      )
    }
    return SchemaCorpus(
      samples: resourceSamples + [
        Sample(
          name: "draft2020-12-schema",
          schemaSource: .draft202012MetaSchema,
          instance: loadJSONValue(named: "draft2020-12-schema.instance")
        )
      ]
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
