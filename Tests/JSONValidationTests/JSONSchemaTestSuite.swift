import JSONSchema
import Foundation
import Testing

public struct JSONSchemaTest: Sendable, Codable, CustomStringConvertible {
  struct Spec: Sendable, Codable {
    let core: String
    let quote: String
  }

  struct TestCase: Sendable, Codable, CustomStringConvertible {
    let description: String
    let data: JSONValue
    let valid: Bool
  }

  public let description: String
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
    print(schemaTest.schema)

    for testCase in schemaTest.tests {
      let issues = schemaTest.schema.validate(testCase.data)

      #expect(testCase.valid ? issues == nil : issues != nil, "\(testCase); should be \(testCase.valid ? "valid" : "invalid") but recieved \(issues?.map(\.description).joined(separator: ", ") ?? "no issues"); schema: \(schemaTest.schema)")
    }
  }
}
