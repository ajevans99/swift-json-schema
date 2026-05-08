import JSONSchema
import SnapshotTesting
import Testing

struct MetaSchemaValidationTests {
  // MARK: - Passing cases (boolean isValid is the only assertion that matters)

  @Test func validateValidSchemaAgainstMetaSchema() throws {
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

  @Test func dialectValidateSchemaValid() throws {
    let rawSchema: JSONValue = [
      "type": "string",
      "minLength": 1,
      "maxLength": 100,
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid, "Valid schema should pass meta-schema validation")
  }

  @Test func validateComplexSchemaAgainstMetaSchema() throws {
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
    let trueSchema: JSONValue = .boolean(true)
    let falseSchema: JSONValue = .boolean(false)

    let schema1 = try Schema(rawSchema: trueSchema, context: Context(dialect: .draft2020_12))
    let result1 = try schema1.validateAgainstMetaSchema()
    #expect(result1.isValid, "Boolean true schema should pass meta-schema validation")

    let schema2 = try Schema(rawSchema: falseSchema, context: Context(dialect: .draft2020_12))
    let result2 = try schema2.validateAgainstMetaSchema()
    #expect(result2.isValid, "Boolean false schema should pass meta-schema validation")
  }

  // MARK: - Failure cases (snapshot the actual error structure)
  //
  // Now that #149 makes validation output deterministic across processes,
  // these snapshots can lock in the exact error tree the meta-schema
  // produces — both as regression coverage and as documentation of what
  // a meta-schema failure looks like to downstream consumers.

  @Test func validateInvalidSchemaAgainstMetaSchema() throws {
    // type: 123 is not a string or array of strings.
    let rawSchema: JSONValue = [
      "type": 123,
      "properties": [
        "name": ["type": "string"]
      ],
    ]

    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    let result = try schema.validateAgainstMetaSchema()
    #expect(result.isValid == false)
    assertSnapshot(of: result, as: .json)
  }

  @Test func dialectValidateSchemaInvalid() throws {
    // Both "type" (invalid enum values) and "minLength" (string instead
    // of number) violate meta-schema rules.
    let rawSchema: JSONValue = [
      "type": ["not", "a", "valid", "type", "array"],
      "minLength": "not a number",
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid == false)
    assertSnapshot(of: result, as: .json)
  }

  @Test func validateSchemaWithInvalidMinimumType() throws {
    // minimum should be a number, not a string.
    let rawSchema: JSONValue = [
      "type": "integer",
      "minimum": "10",
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid == false)
    assertSnapshot(of: result, as: .json)
  }

  @Test func validateSchemaWithInvalidProperties() throws {
    // properties should be an object whose values are schemas.
    let rawSchema: JSONValue = [
      "type": "object",
      "properties": "not an object",
    ]

    let result = try Dialect.draft2020_12.validateSchema(rawSchema)
    #expect(result.isValid == false)
    assertSnapshot(of: result, as: .json)
  }
}
