import Foundation
@testable import JSONSchema2
import Testing

@Suite(.serialized)
struct JSONSchemaTestSuite {
  static let fileLoader = FileLoader<[JSONSchemaTest]>(subdirectory: "JSON-Schema-Test-Suite/tests/draft2020-12")

  static let unsupportedFilePaths: [String] = [
    "unevaluatedItems.json",
    "unevaluatedProperties.json",
  ]

  static let flattenedArguments: [(schemaTest: JSONSchemaTest, path: String)] = {
    fileLoader.loadAllFiles()
      .filter { unsupportedFilePaths.contains($0.fileName) == false }
      .sorted(by: { $0.fileName < $1.fileName })
//      .filter { $0.fileName == "refRemote.json" }
      .filter { $0.fileName == "infinite-loop-detection.json" }
      .flatMap { path, schemaTests in
        schemaTests.map { ($0, path) }
      }
  }()

  static let remotes: [String: Schema] = RemoteLoader().loadSchemas()

  @Test(arguments: flattenedArguments)
  func schemaTest(_ schemaTest: JSONSchemaTest, path: String) throws {
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

  @Test func debugger() throws {
    let testSchema = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$id": "http://localhost:1234/draft2020-12/scope_change_defs1.json",
          "type" : "object",
          "properties": {"list": {"$ref": "baseUriChangeFolder/"}},
          "$defs": {
              "baz": {
                  "$id": "baseUriChangeFolder/",
                  "type": "array",
                  "items": {"$ref": "folderInteger.json"}
              }
          }
      }
      """

    let testCase = """
      {"list": [1]}
      """

    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: testSchema.data(using: .utf8)!)
    let schema = try #require(try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes)))
    let result = try #require(try schema.validate(instance: testCase))
    dump(result)
//    dump(schema.context)
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
