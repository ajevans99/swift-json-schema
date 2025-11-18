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

    let nestedSchema: JSONValue = [
      "type": "object",
      "properties": [
        "name": ["type": "string", "minLength": 2]
      ],
    ]

    let nestedInstance: JSONValue = ["name": "a"]
    let schema = try Schema(rawSchema: nestedSchema, context: .init(dialect: .draft2020_12))

    let detailedOutput = try schema.validate(nestedInstance, output: .detailed)
    let detailedObject = try #require(detailedOutput.object)
    let detailedErrors = try #require(detailedObject["errors"]?.array)
    #expect(detailedErrors.count == 1)
    let detailedLeaf = try #require(detailedErrors.first?.object)
    #expect(detailedLeaf["keywordLocation"] == .string("/properties/name/minLength"))

    let verboseOutput = try schema.validate(nestedInstance, output: .verbose)
    let verboseObject = try #require(verboseOutput.object)
    let verboseErrors = try #require(verboseObject["errors"]?.array)
    #expect(verboseErrors.count == 1)
    let verboseBranch = try #require(verboseErrors.first?.object)
    #expect(verboseBranch["keywordLocation"] == .string("/properties"))
    let nestedVerboseErrors = try #require(verboseBranch["errors"]?.array)
    let nestedVerboseLeaf = try #require(nestedVerboseErrors.first?.object)
    #expect(nestedVerboseLeaf["keywordLocation"] == .string("/properties/name/minLength"))
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
    let loader = FileLoader<JSONValue>(
      bundle: .jsonSchemaResources
    )
    let rawSchema = try #require(loader.loadFile(named: "validation"))
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
    let loader = FileLoader<JSONValue>(
      bundle: .jsonSchemaResources
    )
    let raw = try #require(loader.loadFile(named: "core"))
    let defsSchema = try #require(raw.object?["properties"]?.object?["$defs"])
    let schema = try Schema(
      rawSchema: defsSchema,
      context: Context(dialect: .draft2020_12),
      baseURI: URL(string: "https://json-schema.org/draft/2020-12/meta/core")!
    )

    let result = schema.validate(["foo": ["type": 1]])
    #expect(result.isValid == false, "\(result)")
  }

  @Test func absoluteKeywordLocationLocalRef() throws {
    let baseURL = try #require(URL(string: "https://example.com/schemas/root"))
    let rawSchema: JSONValue = [
      "$id": JSONValue.string(baseURL.absoluteString),
      "$defs": [
        "nonEmpty": [
          "type": "string",
          "minLength": 2,
        ]
      ],
      "allOf": [
        ["$ref": "#/$defs/nonEmpty"]
      ],
    ]

    let schema = try Schema(
      rawSchema: rawSchema,
      context: Context(dialect: .draft2020_12),
      baseURI: baseURL
    )

    let result = schema.validate(.string(""))
    let allOfError = try #require(result.errors?.first)
    #expect(allOfError.keywordLocation == JSONPointer(tokens: ["allOf"]))

    let referenceFailure = try #require(allOfError.errors?.first)
    #expect(referenceFailure.keywordLocation == JSONPointer(tokens: ["allOf", "0", "$ref"]))

    let dereferencedError = try #require(referenceFailure.errors?.first)
    #expect(
      dereferencedError.keywordLocation
        == JSONPointer(tokens: ["allOf", "0", "$ref", "minLength"])
    )
    #expect(
      dereferencedError.absoluteKeywordLocation
        == "https://example.com/schemas/root#/$defs/nonEmpty/minLength"
    )
  }

  @Test func absoluteKeywordLocationRemoteRef() throws {
    let remoteURL = "https://example.com/strings.json"
    let remoteSchema: JSONValue = [
      "$id": JSONValue.string(remoteURL),
      "type": "string",
      "minLength": 5,
    ]

    let schema = try Schema(
      rawSchema: ["$ref": JSONValue.string(remoteURL)],
      context: Context(dialect: .draft2020_12, remoteSchema: [remoteURL: remoteSchema]),
      baseURI: URL(string: "https://example.com/root.json")!
    )

    let result = schema.validate(JSONValue.string("abc"))
    let refError = try #require(result.errors?.first)

    let dereferencedError = try #require(refError.errors?.first)
    #expect(dereferencedError.keywordLocation == JSONPointer(tokens: ["$ref", "minLength"]))
    #expect(
      dereferencedError.absoluteKeywordLocation
        == "https://example.com/strings.json#/minLength"
    )
  }
}
