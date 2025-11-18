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

  @Test func validationOutputAPI() throws {
    let trueSchema = try Schema(rawSchema: .boolean(true), context: .init(dialect: .draft2020_12))
    let basicOutput = try trueSchema.validate(.string("ok"), output: .basic)
    let outputObject = try #require(basicOutput.object)
    #expect(outputObject["valid"] == .boolean(true))
    #expect(outputObject["keywordLocation"] == .string(""))
    #expect(outputObject["instanceLocation"] == .string(""))

    let falseSchema = try Schema(rawSchema: .boolean(false), context: .init(dialect: .draft2020_12))
    let flagOutput = try falseSchema.validate(.string("ok"), output: .flag)
    #expect(flagOutput == .boolean(false))
  }

  @Test func metaSchema() throws {
    let metaSchema = try Dialect.draft2020_12.loadMetaSchema()
    let result = metaSchema.validate(.object(["minLength": 1]))
    #expect(result.isValid == true)
  }

  @Test func formatValidators() throws {
    let rawSchema: JSONValue = [
      "type": "string",
      "format": "uuid",
    ]

    let valid: JSONValue = .string("00000000-0000-0000-0000-000000000000")
    let invalid: JSONValue = .string("not-a-uuid")

    let schema = try Schema(
      rawSchema: rawSchema,
      context: Context(
        dialect: .draft2020_12,
        formatValidators: [UUIDFormatValidator()]
      )
    )

    #expect(schema.validate(valid).isValid)
    #expect(schema.validate(invalid).isValid == false)
  }

  @Test func metaschemaRejectsInvalidDefinitions() throws {
    let metaschema = try Dialect.draft2020_12.loadMetaSchema()
    let metaURL = try #require(URL(string: "https://json-schema.org/draft/2020-12/schema"))
    let metaAnchor = try #require(metaschema.context.documentDynamicAnchors[metaURL]?["meta"])
    #expect(metaAnchor.pointer == JSONPointer())
    let invalid: JSONValue = [
      "$defs": [
        "foo": [
          "type": 1
        ]
      ]
    ]

    let result = metaschema.validate(invalid)
    #expect(result.isValid == false, "\(result)")
  }

  @Test func validationMetaRejectsBadTypeKeyword() throws {
    let path = URL(
      fileURLWithPath: "Sources/JSONSchema/Resources/draft2020-12/meta/validation.json"
    )
    let data = try Data(contentsOf: path)
    let rawSchema = try JSONDecoder().decode(JSONValue.self, from: data)
    let schema = try Schema(
      rawSchema: rawSchema,
      context: Context(dialect: .draft2020_12),
      baseURI: URL(string: "https://json-schema.org/draft/2020-12/meta/validation")!
    )

    let result = schema.validate(["type": 1])
    #expect(result.isValid == false, "\(result)")
  }

  @Test func dynamicRefMetaValidationRejectsBadType() throws {
    let metaschema = try Dialect.draft2020_12.loadMetaSchema()
    let baseURL = try #require(URL(string: "https://json-schema.org/draft/2020-12/schema"))
    let dynamicRefSchema = try Schema(
      rawSchema: ["$dynamicRef": "#meta"],
      context: metaschema.context,
      baseURI: baseURL
    )

    let result = dynamicRefSchema.validate(["type": 1])
    #expect(result.isValid == false, "\(result)")
  }

  @Test func defsSchemaRejectsInvalidEntry() throws {
    let data = try Data(
      contentsOf: URL(fileURLWithPath: "Sources/JSONSchema/Resources/draft2020-12/meta/core.json")
    )
    let raw = try JSONDecoder().decode(JSONValue.self, from: data)
    let defsSchema = try #require(raw.object?["properties"]?.object?["$defs"])
    let schema = try Schema(
      rawSchema: defsSchema,
      context: Context(dialect: .draft2020_12),
      baseURI: URL(string: "https://json-schema.org/draft/2020-12/meta/core")!
    )

    let result = schema.validate(["foo": ["type": 1]])
    #expect(result.isValid == false, "\(result)")
  }
}
