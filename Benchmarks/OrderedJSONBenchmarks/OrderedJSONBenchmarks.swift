import Benchmark
import Foundation
import OrderedJSON

/// Benchmark suite for ``OrderedJSON.JSONValue.parse`` and
/// ``OrderedJSON.JSONValue.serialized``, comparing against Foundation's
/// `JSONDecoder` / `JSONSerialization` / `JSONEncoder`.
///
/// Run with:
///
///     cd Benchmarks
///     swift package --allow-writing-to-package-directory benchmark
///
/// The corpus is small and committed to the repo so anyone can run these
/// without external downloads. See `Benchmarks/README.md` for notes on
/// adding cases and updating baselines.
nonisolated(unsafe) let benchmarks = {
  Benchmark.defaultConfiguration = .init(
    metrics: [.wallClock, .cpuTotal, .mallocCountTotal],
    warmupIterations: 3,
    maxDuration: .seconds(2),
    maxIterations: 1000
  )

  // MARK: - Corpus loading

  // Vendored corpus: files live next to this source via SPM resources.
  let corpus = Corpus.load()

  // MARK: - Parse benchmarks
  //
  // For each corpus file: parse via OrderedJSON, JSONDecoder<JSONValue>,
  // and JSONSerialization. Naming convention is
  // "parse · <case> · <parser>" so result tables sort cleanly.

  for sample in corpus.samples {
    Benchmark("parse · \(sample.name) · OrderedJSON") { benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(try JSONValue.parse(sample.data))
      }
    }

    Benchmark("parse · \(sample.name) · JSONDecoder") { benchmark in
      let decoder = JSONDecoder()
      for _ in benchmark.scaledIterations {
        blackHole(try decoder.decode(JSONValue.self, from: sample.data))
      }
    }

    Benchmark("parse · \(sample.name) · JSONSerialization") { benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(
          try JSONSerialization.jsonObject(with: sample.data, options: [.fragmentsAllowed])
        )
      }
    }
  }

  // MARK: - Serialize benchmarks
  //
  // For each corpus file (parsed once at setup): re-emit via OrderedJSON
  // and via JSONEncoder. JSONEncoder's `.sortedKeys` is the apples-to-
  // apples comparison since it's the only Foundation flag that produces
  // stable output across processes.

  for sample in corpus.samples {
    let value = try! JSONValue.parse(sample.data)

    Benchmark("serialize · \(sample.name) · OrderedJSON") { benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(try value.serializedData())
      }
    }

    Benchmark("serialize · \(sample.name) · JSONEncoder.sortedKeys") { benchmark in
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      for _ in benchmark.scaledIterations {
        blackHole(try encoder.encode(value))
      }
    }
  }

  // MARK: - Round-trip benchmarks
  //
  // The "parse → emit → parse" loop is the workload that
  // motivated all of #149: anything that ingests JSON, validates, and
  // re-emits (snapshot tests, signed payloads, generated artifacts) hits
  // this exact pattern.

  for sample in corpus.samples {
    Benchmark("roundtrip · \(sample.name) · OrderedJSON") { benchmark in
      for _ in benchmark.scaledIterations {
        let v1 = try JSONValue.parse(sample.data)
        let bytes = try v1.serializedData()
        blackHole(try JSONValue.parse(bytes))
      }
    }
  }
}

// MARK: - Corpus

private struct Corpus: Sendable {
  let samples: [Sample]

  struct Sample: Sendable {
    let name: String
    let data: Data
  }

  static func load() -> Corpus {
    let bundle = Bundle.module
    let names = [
      "small",
      "wide-object",
      "deep-array",
      "poll-instance",
      "users-array",
    ]
    let samples = names.map { name -> Sample in
      guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: nil) else {
        fatalError(
          """
          Could not locate \(name).json in the benchmark resource bundle. \
          The package's resources block should be processing \
          Benchmarks/OrderedJSONBenchmarks/Resources/ into the executable bundle.
          """
        )
      }
      do {
        let data = try Data(contentsOf: url)
        return Sample(name: name, data: data)
      } catch {
        fatalError("Failed to load \(name).json: \(error)")
      }
    }
    return Corpus(samples: samples)
  }
}
