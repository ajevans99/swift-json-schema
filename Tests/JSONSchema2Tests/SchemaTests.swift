import Testing
import Foundation

@testable import JSONSchema2

struct SchemaTests {
  @Test func trueBooleanSchema() throws {
    let truthy: JSONValue = .boolean(true)
    let schema = try #require(try Schema(rawSchema: truthy, context: Context(dialect: .draft2020_12)))
    #expect(schema.validate(.integer(4)).valid)
  }

  @Test func falseBooleanSchema() throws {
    let falsy: JSONValue = .boolean(false)
    let schema = try #require(try Schema(rawSchema: falsy, context: Context(dialect: .draft2020_12)))
    #expect(schema.validate(.integer(4)).valid == false)
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
    let schema = try #require(try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12)).schema as? ObjectSchema)

    #expect(rawSchema.object?.keys.count == schema.keywords.count)
  }

  @Test func defsAndRefs() throws {
    let rawSchema: JSONValue = [
      "$defs": [
        "positiveInteger": [
          "type": "integer",
          "minimum": 1
        ]
      ],
      "type": "object",
      "properties": [
        "age": ["$ref": "#/$defs/positiveInteger"]
      ]
    ]

    let validInstance: JSONValue = ["age": 1]
    let invalidInstance: JSONValue = ["age": 0]

    let schema = try #require(try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12)))
    #expect(schema.validate(validInstance).valid)
    #expect(schema.validate(invalidInstance).valid == false)
  }

  @Test func validationResult() throws {
    let rawSchema: JSONValue = [
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer", "minimum": 0]
      ]
    ]

    let instance: JSONValue = ["name": 123, "age": -5]

    let schema = try #require(try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12)))
    let result = schema.validate(instance)
    dump(result)
    #expect(result.valid == false)
    #expect(result.errors?.count == 1)
    #expect(result.annotations?.count == 1)
  }

  @Test func debugger() throws {
    let testSchema = """
      {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$defs": {
                "tilde~field": {"type": "integer"},
                "slash/field": {"type": "integer"},
                "percent%field": {"type": "integer"}
            },
            "properties": {
                "tilde": {"$ref": "#/$defs/tilde~0field"},
                "slash": {"$ref": "#/$defs/slash~1field"},
                "percent": {"$ref": "#/$defs/percent%25field"}
            }
        }
      """

    let testCase = """
      {"slash": "aoeu"}
      """

    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: testSchema.data(using: .utf8)!)
    let schema = try #require(try Schema(rawSchema: rawSchema, context: .init(dialect: .draft2020_12)))
    #expect((try! schema.validate(instance: testCase).valid) == false)
  }
}
