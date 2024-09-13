import Foundation
import JSONSchema2
import Testing

struct JSONSchemaTestSuite {
  static let fileLoader = FileLoader<[JSONSchemaTest]>(subdirectory: "draft2020-12")

  static let unsupportedFilePaths = [String]()

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
      let validationResult = schemaTest.schema.validate(testCase.data)

      let comment: () -> Testing.Comment = {
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
  let schema: Schema
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
