import Foundation
import Testing

@testable import JSONSchema

struct VocabularyTests {
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
    
    #expect(throws: (any Error).self) {
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
}