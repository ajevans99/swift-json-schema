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
}