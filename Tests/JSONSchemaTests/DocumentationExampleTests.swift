import JSONSchema
import Testing

struct DocumentationExampleTests {
  @Test func readMeExistingSchema() throws {
    let externalSchema = try Schema(
      instance: #"{"type": "string", "minLength": 3}"#
    )
    let validation = try externalSchema.validate(instance: #""hi""#)
    #expect(!validation.isValid)

    let diagnostics = try validation.renderedOutput(level: .basic)
    let errors = try #require(diagnostics.object?["errors"]?.array)
    #expect(errors.first?.object?["keywordLocation"] == "/minLength")
    #expect(errors.first?.object?["instanceLocation"] == "")
  }

  @Test func loadingSchemaAndRenderingDiagnostics() throws {
    let schemaJSON = """
      {
        "type": "object",
        "properties": {
          "name": { "type": "string", "minLength": 1 },
          "age": { "type": "integer", "minimum": 0 }
        },
        "required": ["name", "age"]
      }
      """
    let schema = try Schema(
      rawSchema: JSONValue.parse(schemaJSON),
      context: Context(dialect: .draft2020_12)
    )
    let payload: JSONValue = ["name": "Ada", "age": -1]
    let result = schema.validate(payload)
    #expect(!result.isValid)

    let diagnostics = try result.renderedOutput(level: .basic)
    let errors = try #require(diagnostics.object?["errors"]?.array)
    #expect(errors.count == 1)
    #expect(errors.first?.object?["instanceLocation"] == "/age")
    #expect(errors.first?.object?["keywordLocation"] == "/properties/age/minimum")
    #expect(try JSONValue.parse(diagnostics.serialized(options: .pretty)) == diagnostics)
    #expect(try result.renderedOutput(level: .flag) == .boolean(false))
    #expect(try schema.validateAgainstMetaSchema().isValid)
  }

  @Test func externalSchemaRegistry() throws {
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        "https://example.com/nonempty-string": [
          "type": "string",
          "minLength": 1,
        ]
      ]
    )
    let referenced = try Schema(
      rawSchema: ["$ref": "https://example.com/nonempty-string"],
      context: context
    )
    #expect(referenced.validate(.string("Ada")).isValid)
    #expect(!referenced.validate(.string("")).isValid)
  }

  @Test func optInFormats() throws {
    let rawSchema: JSONValue = ["type": "string", "format": "email"]
    let emailSchema = try Schema(
      rawSchema: rawSchema,
      context: Context(
        dialect: .draft2020_12,
        formatValidators: DefaultFormatValidators.all
      )
    )
    #expect(!emailSchema.validate(.string("not-an-email")).isValid)
    #expect(emailSchema.validate(.string("ada@example.com")).isValid)

    let defaultSchema = try Schema(
      rawSchema: rawSchema,
      context: Context(dialect: .draft2020_12)
    )
    #expect(defaultSchema.validate(.string("not-an-email")).isValid)
  }
}
