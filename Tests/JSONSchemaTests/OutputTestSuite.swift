import Foundation
import Testing

@testable import JSONSchema

struct OutputTestSuite {
  private static let supportedFormats: [String: ValidationOutputLevel] = [
    "basic": .basic,
    "detailed": .detailed,
    "verbose": .verbose,
  ]

  static let fileLoader = FileLoader<[OutputTestDocument]>(
    subdirectory: "JSON-Schema-Test-Suite/output-tests/draft2020-12/content"
  )

  static let flattenedArguments: [(testCase: OutputTestDocument, path: URL)] = {
    fileLoader.loadAllFiles()
      .flatMap { path, documents in
        documents.map { ($0, path) }
      }
  }()

  static let remotes: [String: JSONValue] = RemoteLoader().loadSchemas()

  @Test(arguments: flattenedArguments)
  func outputTest(_ testDocument: OutputTestDocument, path: URL) throws {
    let schema = try Schema(
      rawSchema: testDocument.schema,
      context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes),
      baseURI: path
    )

    for test in testDocument.tests {
      let validationResult = schema.validate(test.data)
      var renderedOutputs: [ValidationOutputLevel: JSONValue] = [:]

      for (format, outputSchemaJSON) in test.output {
        guard let level = Self.supportedFormats[format] else { continue }

        let validationValue: JSONValue
        if let cached = renderedOutputs[level] {
          validationValue = cached
        } else {
          let rendered = try validationResult.renderedOutput(level: level)
          renderedOutputs[level] = rendered
          validationValue = rendered
        }

        let outputSchema = try Schema(
          rawSchema: outputSchemaJSON,
          context: .init(dialect: .draft2020_12, remoteSchema: Self.remotes),
          baseURI: path
        )

        let outputValidation = outputSchema.validate(validationValue)

        let comment: () -> Testing.Comment = {
          """
          Output Test: \"\(testDocument.description)\" @ \(path)
          Format: \(format)
          ```json
          \(try! testDocument.schema.json())
          ```

          Test Case: \"\(test.description)\"
          ```json
          \(try! test.data.json())
          ```

          Output:
          ```json
          \(try! validationResult.json())
          ```
          """
        }

        #expect(outputValidation.isValid, comment())
      }
    }
  }
}

struct OutputTestDocument: Sendable, Codable {
  struct TestCase: Sendable, Codable {
    let description: String
    let comment: String?
    let data: JSONValue
    let output: [String: JSONValue]
  }

  let description: String
  let comment: String?
  let schema: JSONValue
  let tests: [TestCase]
}
