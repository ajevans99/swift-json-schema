import Foundation
import Testing

@testable import JSONSchema

struct JSONSchemaTestSuite {
  static let fileLoader = FileLoader<[JSONSchemaTest]>(
    subdirectory: "JSON-Schema-Test-Suite/tests/draft2020-12"
  )

  static let unsupportedFilePaths: [String] = []

  /// Test cases known to fail today, skipped from the official suite to keep
  /// CI green while the underlying gaps are tracked. Each entry must include
  /// a `reason` linking to the issue or PR that will resolve it. Filter
  /// applies at the `(group, case)` granularity — a `nil` `testCase` skips
  /// every case in the group; a non-nil value skips just that one.
  static let unsupportedTests:
    [(path: String, description: String, testCase: String?, reason: String)] = []

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
    let pathFile = path.lastPathComponent
    let groupSkipped = Self.unsupportedTests.contains { entry in
      entry.path == pathFile
        && entry.description == schemaTest.description
        && entry.testCase == nil
    }
    guard !groupSkipped else { return }

    let schema = try Schema(
      rawSchema: schemaTest.schema,
      context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes)
    )

    for testCase in schemaTest.tests {
      let caseSkipped = Self.unsupportedTests.contains { entry in
        entry.path == pathFile
          && entry.description == schemaTest.description
          && entry.testCase == testCase.description
      }
      guard !caseSkipped else { continue }

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
        - Recieved: \(validationResult.isValid)

        Full result:
        ```json
        \(try! validationResult.json())
        ```
        """
      }

      #expect(
        testCase.valid == validationResult.isValid,
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
  //    let schema = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes))
  //    let result = try schema.validate(instance: testCase)
  //    dump(result)
  //    #expect((result.isValid) == false, "\(result)")
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
  func toJSONString() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    return String(decoding: data, as: UTF8.self)
  }

  func toJSONValue() throws -> JSONValue {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(self)
    return try JSONDecoder().decode(JSONValue.self, from: data)
  }
}

extension Schema {
  /// Pretty-printed JSON of this schema in declaration order. Used for
  /// failure diagnostics in the test-suite drivers; preserves the order
  /// the schema author wrote keys in (rather than the alphabetical order
  /// `JSONEncoder.outputFormatting.sortedKeys` would emit), so debugging
  /// output mirrors what consumers actually see.
  func json() throws -> String {
    try (try toJSONValue()).serialized(options: .pretty)
  }
}

extension JSONValue {
  func json() throws -> String {
    try serialized(options: .pretty)
  }
}

extension ValidationResult {
  func json() throws -> String {
    try (try toJSONValue()).serialized(options: .pretty)
  }
}
