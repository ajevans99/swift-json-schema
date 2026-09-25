import Testing

@testable import JSONSchema

struct ReferenceResolutionFailureTests {
  @Test func failedResolutionCanBeRetriedAndSuccessIsCached() throws {
    let context = Context(dialect: .draft2020_12)
    let reference = "https://example.com/eventually-available"
    let schema = try Schema(
      rawSchema: ["$ref": .string(reference)],
      context: context
    )

    #expect(!schema.validate("hello").isValid)

    context.remoteSchemaStorage = [reference: ["type": "string"]]
    #expect(schema.validate("hello").isValid)
    #expect(!schema.validate(42).isValid)

    // Replacing the shared registry entry must not replace the initialized reference.
    context.cacheSchema(try Schema(rawSchema: false, context: context), at: reference)
    #expect(schema.validate("hello").isValid)
    #expect(!schema.validate(42).isValid)
  }

  @Test(
    arguments: ["$ref", "$dynamicRef"],
    ["#/$defs/missing", "#missing", "#/$defs/text/missing"]
  )
  func unresolvedFragmentDoesNotFallBackToTheReferencingRoot(
    keyword: String,
    reference: String
  ) throws {
    let schema = try Schema(
      rawSchema: .object([
        keyword: .string(reference),
        "$defs": ["text": ["type": "string"]],
      ]),
      context: Context(dialect: .draft2020_12)
    )
    let result = schema.validate("hello")
    #expect(!result.isValid)
    let error = try #require(result.errors?.first)
    #expect(error.keyword == keyword)
    #expect(error.message.contains("Unable to resolve"))
  }

  @Test(arguments: ["$ref", "$dynamicRef"])
  func aMissingFragmentInABooleanDocumentIsNotTheWholeDocument(keyword: String) throws {
    let schema = try Schema(
      rawSchema: .object([keyword: "https://example.com/boolean#/missing"]),
      context: Context(
        dialect: .draft2020_12,
        remoteSchema: ["https://example.com/boolean": true]
      )
    )
    #expect(!schema.validate("hello").isValid)
  }

  @Test(arguments: ["", "#", "#/$defs/text", "#text"])
  func wholeDocumentsAndExistingFragmentsStillResolve(fragment: String) throws {
    let schema = try Schema(
      rawSchema: ["$ref": .string("https://example.com/document" + fragment)],
      context: Context(
        dialect: .draft2020_12,
        remoteSchema: [
          "https://example.com/document": [
            "type": "string",
            "$defs": ["text": ["$anchor": "text", "type": "string"]],
          ]
        ]
      )
    )
    #expect(schema.validate("hello").isValid)
    #expect(!schema.validate(42).isValid)
  }
}
