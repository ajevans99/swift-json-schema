import JSONSchema
import OrderedCollections
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
          "https://example.com/vocab/other": false,
        ])
        .anchor("nameAnchor")
        .dynamicAnchor("dynAnchor")
        .dynamicRef("#dynAnchor")
        .ref("#someRef")
        .recursiveAnchor("recAnchor")
        .recursiveRef("#recAnchor")
    }

    let expected: OrderedDictionary<String, JSONValue> = [
      "$id": "https://example.com/schema",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$vocabulary": [
        "https://example.com/vocab/core": true,
        "https://example.com/vocab/other": false,
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

  // Regression for #149 / PR #155: the DSL must preserve the *declared* key
  // order of `vocabulary(_:)` (and other dictionary-literal accepting helpers)
  // through to the emitted JSON. KeyValuePairs makes this possible.
  @Test func vocabularyPreservesDeclarationOrder() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .vocabulary([
          "https://z.example/last": true,
          "https://m.example/middle": false,
          "https://a.example/first": true,
        ])
    }

    let serialized = try sample.schemaValue.value.serialized()
    let zIdx = try #require(serialized.range(of: "z.example/last")).lowerBound
    let mIdx = try #require(serialized.range(of: "m.example/middle")).lowerBound
    let aIdx = try #require(serialized.range(of: "a.example/first")).lowerBound
    // Declared order (z, m, a) — *not* alphabetical (a, m, z).
    #expect(zIdx < mIdx)
    #expect(mIdx < aIdx)
  }
}
