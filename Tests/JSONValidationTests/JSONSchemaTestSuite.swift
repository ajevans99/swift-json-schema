import JSONSchema
import Foundation
import Testing

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
  let schema: RootSchema
  let tests: [TestCase]
}

extension JSONSchemaTest: CustomTestStringConvertible {
  public var testDescription: String { description }
}

struct JSONSchemaTestSuite {
  static let jsonSchemaTestSuiteURL = URL(filePath: #file)
    .deletingLastPathComponent()
    .appending(path: "JSON-Schema-Test-Suite")
    .appending(path: "tests")
    .appending(path: "draft2020-12")

  static let fileLoader = FileLoader<[JSONSchemaTest]>(directoryURL: Self.jsonSchemaTestSuiteURL)

  static let unsupportedFilePaths = [
    "anchor.json",
    "boolean_schema.json",
    "defs.json",
    "dependentRequired.json",
    "dependentSchemas.json",
    "dynamicRef.json",
    "if-then-else.json",
    "ref.json",
    "refRemote.json",
    "vocabulary.json",
  ]

  static let flattenedArguments: [(schemaTest: JSONSchemaTest, path: String)] = {
    fileLoader.loadAllFiles()
      .filter { unsupportedFilePaths.contains($0.fileName) == false }
      .sorted(by: { $0.fileName < $1.fileName })
      .flatMap { path, schemaTests in
        schemaTests.map { ($0, path) }
      }
  }()

  @Test(arguments: flattenedArguments)
  func schemaTest(_ schemaTest: JSONSchemaTest, path: String) throws {
    for testCase in schemaTest.tests {
      let issues = schemaTest.schema.validate(testCase.data)

      var comment: () -> Testing.Comment = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return """
        Schema Test: "\(schemaTest.description)" @ \(path)
        ```json
        \(try! schemaTest.schema.json())
        ```
        
        Test Case: "\(testCase.description)"
        ```json
        \(try! testCase.data.json())
        ```
        
        Results:
        - Expected: \(testCase.valid)
        - Recieved: \(issues?.map(\.description).joined(separator: ", ") ?? "no issues")
        """
      }

      #expect(
        testCase.valid ? issues == nil : issues != nil,
        comment()
      )
    }
  }
}

extension RootSchema {
  func json() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    return String(decoding: data, as: UTF8.self)
  }
}

extension JSONValue {
  func json() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    return String(decoding: data, as: UTF8.self)
  }
}
