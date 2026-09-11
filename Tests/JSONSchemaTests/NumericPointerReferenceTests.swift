import Foundation
import Testing

@testable import JSONSchema

struct NumericPointerReferenceTests {
  @Test(arguments: ["0", "01", "+1", "-0", "-1", "92233720368547758080", "0/~1"])
  func localReferencePreservesDefinitionName(name: String) throws {
    let pointer = JSONPointer(tokens: ["$defs", name])
    let rawSchema: JSONValue = [
      "$defs": .object([name: ["type": "string"]]),
      "properties": [
        "value": ["$ref": .string(pointer.description)]
      ],
    ]
    let schema = try Schema(
      rawSchema: rawSchema,
      context: Context(dialect: .draft2020_12),
      baseURI: URL(string: "https://example.com/schema")!
    )

    #expect(schema.validate(["value": "ok"]).isValid)
    let result = schema.validate(["value": 42])
    #expect(!result.isValid)
    let propertiesError = try #require(result.errors?.first)
    let referenceError = try #require(propertiesError.errors?.first)
    let typeError = try #require(referenceError.errors?.first)
    #expect(typeError.keywordLocation == "/properties/value/$ref/type")
    #expect(
      typeError.absoluteKeywordLocation?.fragment(percentEncoded: false)
        == pointer.appending(.key("type")).jsonPointerString
    )
  }

  @Test(arguments: ["0", "01"])
  func referenceToIdentifierUnderNumericKey(name: String) throws {
    let rawSchema: JSONValue = [
      "$id": "https://example.com/root",
      "$defs": .object([
        name: [
          "$id": "target",
          "type": "string",
        ]
      ]),
      "properties": [
        "value": ["$ref": "target"]
      ],
    ]
    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    #expect(schema.validate(["value": "ok"]).isValid)
    #expect(!schema.validate(["value": 42]).isValid)
  }
}
