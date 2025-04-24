import Foundation
import Testing

@testable import JSONSchema

struct SchemaTests {
  @Test func trueBooleanSchema() throws {
    let truthy: JSONValue = .boolean(true)
    let schema = try Schema(rawSchema: truthy, context: Context(dialect: .draft2020_12))
    #expect(schema.validate(.integer(4)).isValid)
  }

  @Test func falseBooleanSchema() throws {
    let falsy: JSONValue = .boolean(false)
    let schema = try Schema(rawSchema: falsy, context: Context(dialect: .draft2020_12))
    #expect(schema.validate(.integer(4)).isValid == false)
  }

  @Test func invalidSchema() {
    let string = JSONValue.string("Not a valid schema.")
    #expect(throws: SchemaIssue.schemaShouldBeBooleanOrObject) {
      try Schema(rawSchema: string, context: Context(dialect: .draft2020_12))
    }
  }

  @Test func keywordCount() throws {
    let addressRawSchema: JSONValue = [
      "type": "object",
      "properties": [
        "street_address": ["type": "string"],
        "city": ["type": "string"],
        "state": ["type": "string"],
      ],
      "required": ["street_address", "city", "state"],
    ]

    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$vocabulary": [
        "https://json-schema.org/draft/2020-12/vocab/core": true,
        "https://json-schema.org/draft/2020-12/vocab/applicator": true,
        "https://json-schema.org/draft/2020-12/vocab/validation": true,
      ],
      "$id": "https://example.com/my-schema",
      "$ref": "https://example.com/another-schema#",
      "$defs": ["address": addressRawSchema],
      "$anchor": "addressAnchor",
      "$dynamicRef": "#dynamicAnchor",
      "$dynamicAnchor": "dynamicAnchor",
      "$comment": "This is a test schema to demonstrate identifier keywords.",
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer"],
        "address": ["$ref": "#/$defs/address"],
      ],
      "required": ["name", "age"],
    ]
    let schema = try #require(
      try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12)).schema
        as? ObjectSchema
    )

    #expect(rawSchema.object?.keys.count == schema.keywords.count)
  }

  @Test func defsAndRefs() throws {
    let rawSchema: JSONValue = [
      "$defs": [
        "positiveInteger": [
          "type": "integer",
          "minimum": 1,
        ]
      ],
      "type": "object",
      "properties": [
        "age": ["$ref": "#/$defs/positiveInteger"]
      ],
    ]

    let validInstance: JSONValue = ["age": 1]
    let invalidInstance: JSONValue = ["age": 0]

    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    #expect(schema.validate(validInstance).isValid)
    #expect(schema.validate(invalidInstance).isValid == false)
  }

  @Test func validationResult() throws {
    let rawSchema: JSONValue = [
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer", "minimum": 0],
      ],
    ]

    let instance: JSONValue = ["name": 123, "age": -5]

    let schema = try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12))
    let result = schema.validate(instance)
    #expect(result.isValid == false)
    #expect(result.errors?.count == 1)
    #expect(result.annotations == nil)
  }

  @Test func metaSchema() throws {
    let metaSchema = try Dialect.draft2020_12.loadMetaSchema()
    let result = metaSchema.validate(.object(["minLength": 1]))
    #expect(result.isValid == true)
  }
}
