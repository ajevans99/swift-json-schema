import JSONSchema

extension RealWorldCorpus {
  private enum Variant: String, CaseIterable {
    case valid
    case early = "invalid-early"
    case late = "invalid-late"
    case many = "invalid-many"

    func invalidRecord(_ index: Int, count: Int) -> Bool {
      self == .many || (self == .late && index == count - 1)
    }
  }

  static func generatedInstances(named name: String, sizes: [Int]) -> [SchemaCorpus.Instance] {
    sizes.flatMap { count in
      Variant.allCases.map { variant in
        let value: JSONValue
        let errorLocation: (Int) -> String
        let versionLocation: String
        switch name {
        case "openapi-3.1":
          value = openAPI(count: count, variant: variant)
          errorLocation = { "/paths/~1items~1\($0)/get/responses/200/description" }
          versionLocation = "/openapi"
        case "overlay-1.0":
          value = overlay(count: count, variant: variant)
          errorLocation = { "/actions/\($0)/target" }
          versionLocation = "/overlay"
        default:
          fatalError("No deterministic instance generator for \(name)")
        }

        let expectedErrors: [SchemaCorpus.ExpectedError]
        switch variant {
        case .valid:
          expectedErrors = []
        case .early:
          expectedErrors = [.init(keyword: "pattern", instanceLocation: versionLocation)]
        case .late:
          expectedErrors = [.init(keyword: "type", instanceLocation: errorLocation(count - 1))]
        case .many:
          expectedErrors = [
            .init(keyword: "type", instanceLocation: errorLocation(0)),
            .init(keyword: "type", instanceLocation: errorLocation(count - 1)),
          ]
        }

        let levels: [ValidationOutputLevel]
        switch (count, variant) {
        case (_, .many): levels = [.basic, .verbose]
        case (10, .valid): levels = [.basic]
        case (10, .late): levels = [.verbose]
        default: levels = []
        }
        return SchemaCorpus.Instance(
          name: "\(count).\(variant.rawValue)",
          value: value,
          expectedValidity: variant == .valid,
          expectedErrors: expectedErrors,
          outputLevels: levels,
          minimumLeafErrors: variant == .many ? count : 0
        )
      }
    }
  }

  private static func openAPI(count: Int, variant: Variant) -> JSONValue {
    let paths: [(String, JSONValue)] = (0 ..< count)
      .map { index in
        let description: JSONValue = variant.invalidRecord(index, count: count) ? 7 : "OK"
        return (
          "/items/\(index)",
          [
            "get": [
              "operationId": .string("getItem\(index)"),
              "tags": [.string("tag_\(index)")],
              "parameters": [
                ["name": "q", "in": "query", "schema": ["type": "string"]]
              ],
              "responses": ["200": ["description": description]],
            ]
          ]
        )
      }
    return [
      "openapi": variant == .early ? "3.0.3" : "3.1.0",
      "info": ["title": "Benchmark API", "version": "1.0.0"],
      "paths": .object(.init(uniqueKeysWithValues: paths)),
      "tags": .array((0 ..< count).map { ["name": .string("tag_\($0)")] }),
    ]
  }

  private static func overlay(count: Int, variant: Variant) -> JSONValue {
    let actions: [JSONValue] = (0 ..< count)
      .map { index in
        let target: JSONValue =
          variant.invalidRecord(index, count: count)
          ? 7 : .string("$.paths['/items/\(index)'].get")
        return [
          "target": target,
          "description": .string("Update operation \(index)"),
          "update": ["summary": .string("Updated operation \(index)")],
        ]
      }
    return [
      "overlay": variant == .early ? "1.1.0" : "1.0.0",
      "info": ["title": "Benchmark overlay", "version": "1.0.0"],
      "actions": .array(actions),
    ]
  }
}
