import Foundation
import JSONSchema

enum RealWorldCorpus {
  private struct Manifest: Decodable {
    let sources: [Source]

    struct Source: Decodable {
      let name: String
      let schema: String
      let schemaID: String
      let assets: [Asset]
    }

    struct Asset: Decodable {
      let file: String
      let kind: String
    }
  }

  static func load() -> [SchemaCorpus.Sample] {
    let environment = ProcessInfo.processInfo.environment
    let required: Bool
    switch environment["JSONSCHEMA_BENCHMARK_CORPUS"] ?? "optional" {
    case "optional": required = false
    case "required": required = true
    default: fatalError("JSONSCHEMA_BENCHMARK_CORPUS must be optional or required")
    }
    let sizes: [Int]
    switch environment["JSONSCHEMA_BENCHMARK_SIZES"] ?? "pr" {
    case "pr": sizes = [10, 100]
    case "extended": sizes = [10, 100, 1000]
    default: fatalError("JSONSCHEMA_BENCHMARK_SIZES must be pr or extended")
    }

    do {
      guard
        let manifestURL = Bundle.module.url(
          forResource: "real-world-manifest",
          withExtension: "json"
        )
      else {
        fatalError("Missing pinned real-world corpus manifest")
      }
      let manifest = try JSONDecoder()
        .decode(
          Manifest.self,
          from: Data(contentsOf: manifestURL)
        )
      let assets = manifest.sources.flatMap(\.assets)
      let urls = assets.map { Bundle.module.url(forResource: $0.file, withExtension: nil) }
      if urls.allSatisfy({ $0 == nil }) && !required {
        print("JSONSchema real-world corpus absent; run fetch_schema_corpus.py to include it.")
        return []
      }
      for (asset, url) in zip(assets, urls) where url == nil {
        fatalError(
          "Missing real-world corpus asset \(asset.file); run "
            + "python3 Benchmarks/Scripts/fetch_schema_corpus.py before building."
        )
      }

      var schemas: [String: JSONValue] = [:]
      var remotes: [String: JSONValue] = [:]
      for (asset, url) in zip(assets, urls) where asset.kind == "schema" {
        let value = try JSONValue.parse(Data(contentsOf: url!))
        guard value.object?["$schema"]?.string == Dialect.draft2020_12.rawValue,
          let id = value.object?["$id"]?.string, URL(string: id)?.scheme == "https"
        else {
          fatalError("\(asset.file): expected a draft 2020-12 schema with an HTTPS $id")
        }
        schemas[asset.file] = value
        remotes[id] = value
      }
      return manifest.sources.map { source in
        guard let schema = schemas[source.schema],
          schema.object?["$id"]?.string == source.schemaID,
          let baseURI = URL(string: source.schemaID)
        else {
          fatalError("\(source.name): root schema does not match the pinned manifest")
        }
        return SchemaCorpus.Sample(
          name: source.name,
          schemaSource: .downloaded(schema, baseURI: baseURI, remotes: remotes),
          instances: generatedInstances(named: source.name, sizes: sizes),
          isRealWorld: true
        )
      }
    } catch {
      fatalError("Cannot load real-world schema corpus: \(error)")
    }
  }
}
