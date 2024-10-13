import Foundation
@testable import JSONSchema2
import Testing

@Suite(.serialized)
struct JSONSchemaTestSuite {
  static let fileLoader = FileLoader<[JSONSchemaTest]>(subdirectory: "JSON-Schema-Test-Suite/tests/draft2020-12")

  static let unsupportedFilePaths: [String] = [
//    "unevaluatedItems.json",
//    "unevaluatedProperties.json",
  ]

  static let flattenedArguments: [(schemaTest: JSONSchemaTest, path: URL)] = {
    fileLoader.loadAllFiles()
      .filter { unsupportedFilePaths.contains($0.url.lastPathComponent) == false }
//      .sorted(by: { $0.fileName < $1.fileName })
//      .filter { $0.url.lastPathComponent == "refRemote.json" }
//      .filter { $0.url.lastPathComponent == "ref.json" }
//      .filter { $0.url.lastPathComponent == "dynamicRef.json" }
//      .filter { $0.url.lastPathComponent == "anchor.json" }
      .flatMap { path, schemaTests in
        schemaTests.map { ($0, path) }
      }
  }()

  static let remotes: [String: JSONValue] = RemoteLoader().loadSchemas()

  @Test(arguments: flattenedArguments)
  func schemaTest(_ schemaTest: JSONSchemaTest, path: URL) throws {
    for testCase in schemaTest.tests {
      let schema = try #require(try Schema(rawSchema: schemaTest.schema, context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes)))
      let validationResult = schema.validate(testCase.data)

      let comment: () -> Testing.Comment = {
        """
        Schema Test: "\(schemaTest.description)" @ \(path)
        ```json
        \(try! schemaTest.schema.json())
        ```

        Test Case: "\(testCase.description)"
        ```json
        \(try! testCase.data.json())
        ```

        Valid?:
        - Expected: \(testCase.valid)
        - Recieved: \(validationResult.valid)

        Full result:
        ```json
        \(try! validationResult.json())
        ```
        """
      }

      #expect(
        testCase.valid == validationResult.valid,
        comment()
      )
    }
  }

  @Test func debugger0() throws {
    let testSchema = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$ref": "#foo",
        "$defs": {
          "A": {
            "$anchor": "foo",
            "type": "integer"
          }
        }
      }
      """

    let testCase = """
      1
      """

    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: testSchema.data(using: .utf8)!)
    let schema = try #require(try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes)))
    let result = try #require(try schema.validate(instance: testCase))
    dump(result)
    #expect((result.valid) == true, "\(result)")
  }

  @Test func debugger1() throws {
    let testSchema = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "http://localhost:1234/draft2020-12/tree",
        "description": "tree of nodes",
        "type": "object",
        "properties": {
            "meta": {"type": "string"},
            "nodes": {
                "type": "array",
                "items": {"$ref": "node"}
            }
        },
        "required": ["meta", "nodes"],
        "$defs": {
            "node": {
                "$id": "http://localhost:1234/draft2020-12/node",
                "description": "node",
                "type": "object",
                "properties": {
                    "value": {"type": "number"},
                    "subtree": {"$ref": "tree"}
                },
                "required": ["value"]
            }
        }
      }
      """

    let testCase = """
      {
        "meta": "root",
        "nodes": [
          {
            "value": 1,
            "subtree": {
              "meta": "child",
              "nodes": [
                {"value": 1.1},
                {"value": 1.2}
              ]
            }
        },
          {
            "value": 2,
            "subtree": {
              "meta": "child",
              "nodes": [
                {"value": 2.1},
                {"value": 2.2}
              ]
            }
          }
        ]
      }
      """

    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: testSchema.data(using: .utf8)!)
    let schema = try #require(try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes)))
    let result = try #require(try schema.validate(instance: testCase))
    dump(result)
    #expect((result.valid) == true, "\(result)")
  }
}

struct JSONSchemaTest: Sendable, Codable {
  struct Spec: Sendable, Codable {
    let core: String
    let quote: String?
  }

  struct TestCase: Sendable, Codable {
    let description: String
    let data: JSONValue
    let valid: Bool
  }

  let description: String
  let specification: [Spec]?
  let schema: JSONValue
  let tests: [TestCase]
}

extension JSONSchemaTest: CustomTestStringConvertible {
  public var testDescription: String { description }
}

extension Encodable {
  fileprivate func toJsonString() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    return String(decoding: data, as: UTF8.self)
  }
}

extension Schema {
  fileprivate func json() throws -> String {
    try toJsonString()
  }
}

extension JSONValue {
  fileprivate func json() throws -> String {
    try toJsonString()
  }
}

extension ValidationResult {
  fileprivate func json() throws -> String {
    try toJsonString()
  }
}
