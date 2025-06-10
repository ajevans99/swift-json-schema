import Foundation
import Testing

@testable import JSONSchema

struct VocabularyIntegrationTests {
  @Test func testRealWorldVocabularyScenario() throws {
    // Test a schema that mimics the official JSON Schema meta-schema
    let metaSchemaLike = """
    {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://example.com/my-schema",
        "$vocabulary": {
            "https://json-schema.org/draft/2020-12/vocab/core": true,
            "https://json-schema.org/draft/2020-12/vocab/applicator": true,
            "https://json-schema.org/draft/2020-12/vocab/validation": true,
            "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
            "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
            "https://json-schema.org/draft/2020-12/vocab/content": true,
            "https://json-schema.org/draft/2020-12/vocab/unevaluated": true
        },
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "number", "minimum": 0 }
        },
        "required": ["name"]
    }
    """
    
    let jsonData = metaSchemaLike.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)
    
    // Should successfully create the schema
    let schema = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    
    // Test validation with the schema
    let validInstance = JSONValue.object([
      "name": .string("John"),
      "age": .number(30)
    ])
    
    let result = schema.validate(validInstance)
    #expect(result.isValid)
    
    // Test with invalid instance
    let invalidInstance = JSONValue.object([
      "age": .number(-5)  // Missing required "name", invalid age
    ])
    
    let invalidResult = schema.validate(invalidInstance)
    #expect(!invalidResult.isValid)
  }
  
  @Test func testSchemaWithoutValidationVocabulary() throws {
    // Test a schema that omits the validation vocabulary which defines 'minimum'
    // When validation vocab is omitted, minimum should not work, so -5 should pass
    let schemaWithoutValidationVocab = """
    {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$vocabulary": {
            "https://json-schema.org/draft/2020-12/vocab/core": true,
            "https://json-schema.org/draft/2020-12/vocab/applicator": true,
            "https://json-schema.org/draft/2020-12/vocab/meta-data": true
        },
        "type": "object",
        "properties": {
            "name": { "type": "string" },
            "age": { "type": "number", "minimum": 0 }
        },
        "required": ["name"]
    }
    """
    
    let jsonData = schemaWithoutValidationVocab.data(using: .utf8)!
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: jsonData)
    
    // Should successfully create the schema
    let schema = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    
    // Test with -5 - this should pass because validation vocabulary is omitted
    // so 'minimum' keyword is not recognized/active
    let instanceWithNegative = JSONValue.object([
      "name": .string("John"),
      "age": .number(-5)
    ])
    
    let result = schema.validate(instanceWithNegative)
    #expect(result.isValid, "Validation should pass when validation vocabulary is omitted, so minimum constraint is ignored")
    
    // Also test that type validation is also ignored (since type is in validation vocabulary)
    let instanceWithWrongType = JSONValue.object([
      "name": .string("John"),
      "age": .string("not a number")
    ])
    
    let typeResult = schema.validate(instanceWithWrongType)
    #expect(typeResult.isValid, "Type validation should also be ignored since validation vocabulary is omitted")
  }
}