import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONIdentifierBuilderTests {
  @Test func identifierKeywords() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .id("https://example.com/schema")
        .schema("https://json-schema.org/draft/2020-12/schema")
        .vocabulary([
          "https://example.com/vocab/core": true,
          "https://example.com/vocab/other": false
        ])
        .anchor("nameAnchor")
        .dynamicAnchor("dynAnchor")
        .dynamicRef("#dynAnchor")
        .ref("#someRef")
        .recursiveAnchor("recAnchor")
        .recursiveRef("#recAnchor")
    }

    let expected: [String: JSONValue] = [
      "$id": "https://example.com/schema",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$vocabulary": [
        "https://example.com/vocab/core": true,
        "https://example.com/vocab/other": false
      ],
      "$anchor": "nameAnchor",
      "$dynamicAnchor": "dynAnchor",
      "$dynamicRef": "#dynAnchor",
      "$ref": "#someRef",
      "$recursiveAnchor": "recAnchor",
      "$recursiveRef": "#recAnchor",
      "type": "string",
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}
