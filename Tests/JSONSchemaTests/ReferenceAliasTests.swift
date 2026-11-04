import Testing

@testable import JSONSchema

struct ReferenceAliasTests {
  private let alias = "https://mirror.example.com/schemas/common.json"
  private let canonical = "https://example.com/schemas/common.json"

  @Test(arguments: ["$ref", "$dynamicRef"], [false, true])
  func retrievalURLAndCanonicalIDShareTheLoadedDocument(
    keyword: String,
    relative: Bool
  ) throws {
    let remote: JSONValue = [
      "$id": .string(canonical),
      "$defs": ["text": ["type": "string"]],
    ]
    let context = Context(dialect: .draft2020_12, remoteSchema: [alias: remote])
    let first = try Schema(
      rawSchema: .object([
        "$id": "https://mirror.example.com/schemas/host.json",
        keyword: .string((relative ? "common.json" : alias) + "#/$defs/text"),
      ]),
      context: context
    )
    #expect(first.validate("hello").isValid)
    #expect(context.schemaCache[alias] != nil)
    #expect(context.schemaCache[canonical] != nil)

    // A distinct reference must use the context cache, not the first reference's memoized target.
    context.remoteSchemaStorage = [:]
    for url in [alias, canonical] {
      let next = try Schema(
        rawSchema: .object([keyword: .string(url + "#/$defs/text")]),
        context: context
      )
      #expect(next.validate("hello").isValid)
      #expect(!next.validate(42).isValid)
    }
  }

  @Test(arguments: ["$ref", "$dynamicRef"], ["", "#/$defs/text", "#text"])
  func aliasesPreserveCanonicalRelativeReferences(keyword: String, fragment: String) throws {
    let remote: JSONValue = [
      "$id": .string(canonical),
      "$ref": "text.json",
      "$defs": ["text": ["$anchor": "text", "$ref": "text.json"]],
    ]
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        alias: remote,
        "https://example.com/schemas/text.json": ["type": "string"],
        "https://mirror.example.com/schemas/text.json": false,
      ]
    )
    for url in [alias, canonical] {
      let schema = try Schema(
        rawSchema: .object([keyword: .string(url + fragment)]),
        context: context
      )
      #expect(schema.validate("hello").isValid)
      #expect(!schema.validate(42).isValid)
    }
  }

  @Test func aliasFragmentsKeepCanonicalDiagnosticLocations() throws {
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        alias: [
          "$id": .string(canonical),
          "$defs": ["text": ["type": "string"]],
        ]
      ]
    )
    let schema = try Schema(
      rawSchema: ["$ref": .string(alias + "#/$defs/text")],
      context: context
    )
    let result = schema.validate(42)
    #expect(!result.isValid)
    let referenceError = try #require(result.errors?.first)
    let typeError = try #require(referenceError.errors?.first)
    #expect(
      typeError.absoluteKeywordLocation?.absoluteString
        == canonical + "#/$defs/text/type"
    )
  }

  @Test(arguments: ["", "#root", "#/$defs/text", "#text"])
  func relativeDocumentIDsAreResolvedOnlyOnce(fragment: String) throws {
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        alias: [
          "$id": "canonical/common.json",
          "$anchor": "root",
          "$ref": "text.json",
          "$defs": ["text": ["$anchor": "text", "$ref": "text.json"]],
        ],
        "https://mirror.example.com/schemas/canonical/text.json": ["type": "string"],
      ]
    )
    let schema = try Schema(
      rawSchema: ["$ref": .string(alias + fragment)],
      context: context
    )
    #expect(schema.validate("hello").isValid)
    #expect(!schema.validate(42).isValid)
  }

  @Test func dynamicAnchorReachedThroughAnAliasUsesTheOuterScope() throws {
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        alias: [
          "$id": .string(canonical),
          "$dynamicAnchor": "node",
          "type": "string",
        ]
      ]
    )
    let schema = try Schema(
      rawSchema: [
        "$id": "https://example.com/outer",
        "$dynamicRef": .string(alias + "#node"),
        "$defs": ["override": ["$dynamicAnchor": "node", "type": "integer"]],
      ],
      context: context
    )
    #expect(schema.validate(42).isValid)
    #expect(!schema.validate("hello").isValid)
  }
}
