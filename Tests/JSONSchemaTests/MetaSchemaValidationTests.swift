import Foundation
import Testing

@testable import JSONSchema

struct MetaSchemaValidationTests {
  @Test func validateValidSchemaAgainstMetaSchema() throws {
    // A valid schema should pass meta-schema validation
    let rawSchema: JSONValue = [
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer", "minimum": 0],
      ],
    ]

    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    let result = try schema.validateAgainstMetaSchema()
    #expect(result.isValid, "Valid schema should pass meta-schema validation")
  }

  @Test func validateInvalidSchemaAgainstMetaSchema() throws {
    // A schema with an invalid type value should fail meta-schema validation
    let rawSchema: JSONValue = [
      "type": 123,  // type should be a string or array, not a number
      "properties": [
        "name": ["type": "string"],
      ],
    ]

    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    let result = try schema.validateAgainstMetaSchema()
    #expect(result.isValid == false, "Invalid schema should fail meta-schema validation")
    #expect(result.errors != nil, "Invalid schema should have validation errors")
  }

  @Test func dialectValidateSchemaValid() throws {
    // Test the convenience method on Dialect
    let rawSchema: JSONValue = [
      "type": "string",
      "minLength": 1,
      "maxLength": 100,
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid, "Valid schema should pass meta-schema validation")
  }

  @Test func dialectValidateSchemaInvalid() throws {
    // Test the convenience method on Dialect with an invalid schema
    let rawSchema: JSONValue = [
      "type": ["not", "a", "valid", "type", "array"],  // Invalid enum values
      "minLength": "not a number",  // minLength should be a number
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid == false, "Invalid schema should fail meta-schema validation")
  }

  @Test func validateComplexSchemaAgainstMetaSchema() throws {
    // Test a more complex valid schema
    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://example.com/person.schema.json",
      "title": "Person",
      "type": "object",
      "properties": [
        "firstName": [
          "type": "string",
          "description": "The person's first name.",
        ],
        "lastName": [
          "type": "string",
          "description": "The person's last name.",
        ],
        "age": [
          "description": "Age in years",
          "type": "integer",
          "minimum": 0,
        ],
      ],
      "required": ["firstName", "lastName"],
    ]

    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    let result = try schema.validateAgainstMetaSchema()
    #expect(result.isValid, "Complex valid schema should pass meta-schema validation")
  }

  @Test func validateBooleanSchemaAgainstMetaSchema() throws {
    // Boolean schemas are valid schemas
    let trueSchema: JSONValue = .boolean(true)
    let falseSchema: JSONValue = .boolean(false)

    let schema1 = try Schema(rawSchema: trueSchema, context: Context(dialect: .draft2020_12))
    let result1 = try schema1.validateAgainstMetaSchema()
    #expect(result1.isValid, "Boolean true schema should pass meta-schema validation")

    let schema2 = try Schema(rawSchema: falseSchema, context: Context(dialect: .draft2020_12))
    let result2 = try schema2.validateAgainstMetaSchema()
    #expect(result2.isValid, "Boolean false schema should pass meta-schema validation")
  }

  @Test func validateSchemaWithInvalidMinimumType() throws {
    // Schema with invalid minimum value (should be a number, not a string)
    let rawSchema: JSONValue = [
      "type": "integer",
      "minimum": "10",  // Should be a number, not a string
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid == false, "Schema with invalid minimum type should fail")
  }

  @Test func validateSchemaWithInvalidProperties() throws {
    // Schema with invalid properties value (should be an object)
    let rawSchema: JSONValue = [
      "type": "object",
      "properties": "not an object",  // Should be an object
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid == false, "Schema with invalid properties should fail")
  }
}
