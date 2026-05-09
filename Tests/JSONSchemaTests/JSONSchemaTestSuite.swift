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

extension Schema {
  /// Pretty-printed JSON of this schema in declaration order. Used for
  /// failure diagnostics in the test-suite drivers; goes through the
  /// direct ``Schema/jsonValue`` accessor so output reflects the schema
  /// author's declared keyword order without a `JSONEncoder` round-trip.
  func json() throws -> String {
    try jsonValue.serialized(options: .pretty)
  }
}

extension JSONValue {
  /// Pretty-printed JSON of this value, preserving declared key order via
  /// ``OrderedJSON/JSONValue/serialized(options:)``.
  func json() throws -> String {
    try serialized(options: .pretty)
  }
}

extension ValidationResult {
  /// Pretty-printed JSON of this validation result in deterministic order.
  /// Uses the direct ``ValidationResult/jsonValue`` accessor; no
  /// `JSONEncoder` roundtrip required.
  func json() throws -> String {
    try jsonValue.serialized(options: .pretty)
  }
}
