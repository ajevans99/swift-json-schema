import Foundation
import Testing

@testable import JSONSchema

struct JSONSchemaTestSuite {
  static let fileLoader = FileLoader<[JSONSchemaTest]>(
    subdirectory: "JSON-Schema-Test-Suite/tests/draft2020-12"
  )

  static let unsupportedFilePaths: [String] = [
    "dynamicRef.json"
  ]

  static let unsupportedTests: [(path: String, description: String, reason: String)] = [
    ("defs.json", "validate definition against metaschema", "Metaschema uses dynamic references"),
    (
      "unevaluatedItems.json", "unevaluatedItems with $dynamicRef",
      "Dynamic refs not fully supported"
    ),
    (
      "unevaluatedProperies.json", "unevaluatedProperties with $dynamicRef",
      "Dynamic refs not fully supported"
    ),
    ("refRemote.json", "remote HTTP ref with different URN $id", "URN support incomplete"),
    ("refRemote.json", "remote HTTP ref with nested absolute ref", "URN support incomplete"),
    (
      "vocabulary.json", "schema that uses custom metaschema with with no validation vocabulary",
      "Vocabulary not supported yet"
    ),
  ]

  static let flattenedArguments: [(schemaTest: JSONSchemaTest, path: URL)] = {
    fileLoader.loadAllFiles()
      .filter { unsupportedFilePaths.contains($0.url.lastPathComponent) == false }
      .flatMap { path, schemaTests in
        schemaTests.map { ($0, path) }
      }
  }()

  static let remotes: [String: JSONValue] = RemoteLoader().loadSchemas()

  @Test(arguments: flattenedArguments)
  func schemaTest(_ schemaTest: JSONSchemaTest, path: URL) throws {
    guard !Self.unsupportedTests.contains(where: { $0.description == schemaTest.description })
    else {
      return
    }

    let schema = try #require(
      try Schema(
        rawSchema: schemaTest.schema,
        context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes)
      )
    )

    for testCase in schemaTest.tests {
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

  // This is dynamic ref related
  //  @Test func debugger() throws {
  //    let testSchema = """
  //      {
  //          "$schema": "https://json-schema.org/draft/2020-12/schema",
  //          "$ref": "https://json-schema.org/draft/2020-12/schema"
  //      }
  //      """
  //
  //    let testCase = """
  //      {"$defs": {"foo": {"type": 1}}}
  //      """
  //
  //    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: testSchema.data(using: .utf8)!)
  //    let schema = try #require(try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes)))
  //    let result = try #require(try schema.validate(instance: testCase))
  //    dump(result)
  //    #expect((result.valid) == false, "\(result)")
  //  }
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
