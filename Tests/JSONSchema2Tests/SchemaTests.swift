@testable import JSONSchema2
import Testing

struct SchemaTests {
  @Test func trueBooleanSchema() throws {
    let truthy: JSONValue = .boolean(true)
    let schema = try #require(try Schema(rawSchema: truthy))
    #expect(schema.validate(.integer(4)).valid)
  }

  @Test func falseBooleanSchema() throws {
    let falsy: JSONValue = .boolean(false)
    let schema = try #require(try Schema(rawSchema: falsy))
    #expect(schema.validate(.integer(4)).valid == false)
  }

  @Test func invalidSchema() {
    let string = JSONValue.string("Not a valid schema.")
    #expect(throws: SchemaIssue.schemaShouldBeBooleanOrObject) { try Schema(rawSchema: string) }
  }

  @Test func identifierKeywords() throws {
    let addressRawSchema: JSONValue = [
      "type": "object",
      "properties": [
        "street_address": ["type": "string"],
        "city": ["type": "string"],
        "state": ["type": "string"]
      ],
      "required": ["street_address", "city", "state"]
    ]

    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$vocabulary": [
        "https://json-schema.org/draft/2020-12/vocab/core": true,
        "https://json-schema.org/draft/2020-12/vocab/applicator": true,
        "https://json-schema.org/draft/2020-12/vocab/validation": true
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
        "address": ["$ref": "#/$defs/address"]
      ],
      "required": ["name", "age"]
    ]
    let schema = try #require(try Schema(rawSchema: rawSchema).schema as? ObjectSchema)
    let addressSchema = try #require(try Schema(rawSchema: addressRawSchema))

    #expect(
      schema.context
      == Context(
        dialect: .draft2020_12,
        defintions: ["address": addressSchema],
        dynamicAnchors: ["dynamicAnchor": .init()]
      )
    )
    #expect(rawSchema.object?.keys.count == schema.keywords.count)
  }
}
