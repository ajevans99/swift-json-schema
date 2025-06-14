import Foundation
import Testing

@testable import JSONSchema

struct VocabularyTests {
  @Test func testCustomVocabularies() throws {
    // Test schema with custom vocabularies - required one should fail
    let schemaWithCustomRequired = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": true,
              "https://example.com/custom-vocabulary": true
          },
          "type": "string"
      }
      """

    let jsonData = schemaWithCustomRequired.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)

    #expect(
      throws: SchemaIssue.unsupportedRequiredVocabulary("https://example.com/custom-vocabulary")
    ) {
      _ = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    }

    // Test schema with custom vocabularies - optional one should succeed
    let schemaWithCustomOptional = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": true,
              "https://example.com/custom-vocabulary": false,
              "https://another.example.com/optional-vocab": false
          },
          "type": "string"
      }
      """

    let jsonData2 = schemaWithCustomOptional.data(using: .utf8)!
    let rawSchema2 = try JSONDecoder().decode(JSONValue.self, from: jsonData2)

    // Should not throw because custom vocabularies are optional
    let schema = try Schema(rawSchema: rawSchema2, context: .init(dialect: .draft2020_12))
    let result = schema.validate(JSONValue.string("test"))
    #expect(result.isValid)
  }
  @Test func testVocabularyBasic() throws {
    let schemaWithVocabulary = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": true,
              "https://json-schema.org/draft/2020-12/vocab/validation": true
          },
          "type": "string"
      }
      """

    let jsonData = schemaWithVocabulary.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)

    let schema = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    let result = schema.validate(JSONValue.string("test"))
    #expect(result.isValid)
  }

  @Test func testVocabularyWithUnknownRequired() throws {
    let schemaWithUnknownVocabulary = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": true,
              "https://unknown-vocab.example.com/vocab": true
          },
          "type": "string"
      }
      """

    let jsonData = schemaWithUnknownVocabulary.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)

    #expect(
      throws: SchemaIssue.unsupportedRequiredVocabulary("https://unknown-vocab.example.com/vocab")
    ) {
      _ = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    }
  }

  @Test func testVocabularyWithUnknownOptional() throws {
    let schemaWithOptionalVocabulary = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": true,
              "https://unknown-vocab.example.com/vocab": false
          },
          "type": "string"
      }
      """

    let jsonData = schemaWithOptionalVocabulary.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)

    // Should not throw because unknown vocabulary is optional
    let schema = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    let result = schema.validate(JSONValue.string("test"))
    #expect(result.isValid)
  }

  @Test func testVocabularyInvalidFormat() throws {
    let schemaWithInvalidVocabulary = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": "not an object",
          "type": "string"
      }
      """

    let jsonData = schemaWithInvalidVocabulary.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)

    #expect(throws: SchemaIssue.invalidVocabularyFormat) {
      _ = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    }
  }

  @Test func testVocabularyInvalidValueFormat() throws {
    let schemaWithInvalidValue = """
      {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "$vocabulary": {
              "https://json-schema.org/draft/2020-12/vocab/core": "not a boolean"
          },
          "type": "string"
      }
      """

    let jsonData = schemaWithInvalidValue.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)

    #expect(throws: SchemaIssue.invalidVocabularyFormat) {
      _ = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    }
  }
}
