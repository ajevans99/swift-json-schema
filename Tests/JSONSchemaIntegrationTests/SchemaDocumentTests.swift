import CustomDump
import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
private struct DocumentAddress: Equatable {
  static var schemaDefinitionName: String { "Address" }
  let street: String
}

@Schemable
private struct DocumentOrder: Equatable {
  let shipping: DocumentAddress
  @SchemaOptions(.description("Billing address"))
  let billing: DocumentAddress
}

@Schemable
private struct DocumentCollections: Equatable {
  let addresses: [DocumentAddress]
  let byName: [String: DocumentAddress]
  let optional: DocumentAddress?
}

@Schemable
private enum DocumentChoice: Equatable {
  case first(DocumentAddress)
  case second(DocumentAddress)
}

@Schemable
private struct DocumentTree: Equatable {
  static var schemaDefinitionName: String { "Tree" }
  let name: String
  let children: [DocumentTree]
  let choice: DocumentChoice?
}

@Schemable
private struct DocumentForest: Equatable {
  let left: DocumentTree
  let right: DocumentTree
}

@Schemable
private enum DocumentTreeChoice: Equatable {
  case first(DocumentTree)
  case second(DocumentTree)
}

@Schemable
private struct DocumentInlineAddress: Equatable {
  static var schemaDocumentBehavior: SchemaDocumentBehavior { .inline }
  let street: String
}

@Schemable
private struct DocumentModified {
  @ObjectOptions(.additionalProperties(false))
  let address: DocumentAddress
  @SchemaOptions(.orNull(style: .type))
  let nullable: DocumentAddress?
  let optedOut: DocumentInlineAddress
}

// These named schema providers intentionally do not conform to Schemable.
private struct DocumentToken: Equatable {
  let value: String
  static var schema: some JSONSchemaComponent<DocumentToken> {
    JSONString().map(DocumentToken.init)
  }
}

private enum DocumentConversion: Schemable {
  static var schema: some JSONSchemaComponent<DocumentToken> {
    DocumentToken.schema
  }
}

@Schemable
private struct DocumentCompatibility: Equatable {
  let inferred: DocumentToken
  @SchemaOptions(.customSchema(DocumentConversion.self))
  let customized: DocumentToken
}

@Schemable
private struct DocumentNameCollision {
  static var schemaDefinitionName: String { "Address" }
  let different: Bool
}

@Schemable
private struct DocumentEscapedName {
  static var schemaDefinitionName: String { "Address/with~ #%" }
  let street: String
}

@Schemable
private struct DocumentRecursiveInline {
  @ObjectOptions(.additionalProperties(false))
  let first: DocumentTree
  let second: DocumentTree
}

private indirect enum DocumentMutualA: Schemable {
  case b(DocumentMutualB)
  static var schema: JSONComponents.AnySchemaComponent<DocumentMutualA> {
    JSONReusable(DocumentMutualB.self).map(DocumentMutualA.b).eraseToAnySchemaComponent()
  }
}

private indirect enum DocumentMutualB: Schemable {
  case a(DocumentMutualA)
  static var schema: JSONComponents.AnySchemaComponent<DocumentMutualB> {
    JSONReusable(DocumentMutualA.self).map(DocumentMutualB.a).eraseToAnySchemaComponent()
  }
}

struct SchemaDocumentTests {
  @Test func namedTypesPreserveInlineOutputAndUseSiteDescriptions() throws {
    let inline = DocumentOrder.schema.schemaValue
    #expect(inline["$defs"] == nil)
    #expect(inline["properties"]?.object?["shipping"]?.object?["$ref"] == nil)

    let doc = try DocumentOrder.document()
    expectNoDifference(
      doc.schemaValue.value,
      [
        "type": "object",
        "required": ["shipping", "billing"],
        "properties": [
          "shipping": ["$ref": "#/$defs/Address"],
          "billing": ["$ref": "#/$defs/Address", "description": "Billing address"],
        ],
        "$defs": [
          "Address": [
            "type": "object",
            "required": ["street"],
            "properties": ["street": ["type": "string"]],
          ]
        ],
      ]
    )
    let json: JSONValue = ["shipping": ["street": "A"], "billing": ["street": "B"]]
    #expect(doc.definition().validate(json).isValid)
    expectNoDifference(
      try doc.parseAndValidate(json),
      DocumentOrder(shipping: .init(street: "A"), billing: .init(street: "B"))
    )
    #expect(throws: ParseAndValidateIssue.self) {
      try doc.parseAndValidate(["shipping": ["street": 4], "billing": ["street": "B"]])
    }
  }

  @Test func collectionsOptionalsAndUnionBranchesParseAgainstReferences() throws {
    let doc = try DocumentCollections.document()
    let json: JSONValue = [
      "addresses": [["street": "A"]],
      "byName": ["home": ["street": "B"]],
      "optional": nil,
    ]
    expectNoDifference(
      try doc.parseAndValidate(json),
      DocumentCollections(
        addresses: [.init(street: "A")],
        byName: ["home": .init(street: "B")],
        optional: nil
      )
    )
    let choice = try DocumentChoice.document()
    expectNoDifference(
      try choice.parseAndValidate(["first": ["_0": ["street": "A"]]]),
      DocumentChoice.first(.init(street: "A"))
    )
    #expect(throws: ParseAndValidateIssue.self) {
      try choice.parseAndValidate(["first": ["_0": ["street": 4]]])
    }
  }

  @Test func recursiveDefinitionsAreSharedAndParsingRetainsBranchEvaluations() throws {
    let doc = try DocumentForest.document()
    let tree: JSONValue = [
      "name": "root",
      "children": [
        ["name": "leaf", "children": [], "choice": ["second": ["_0": ["street": "A"]]]]
      ],
    ]
    let value: JSONValue = ["left": tree, "right": tree]
    let parsed = try doc.parseAndValidate(value)
    expectNoDifference(
      parsed.left.children.first?.choice,
      .second(.init(street: "A"))
    )
    #expect(doc.schemaValue["properties"]?.object?["left"]?.object?["$dynamicAnchor"] == nil)
    #expect(doc.schemaValue["$defs"]?.object?["Tree"]?.object?["$dynamicAnchor"] != nil)
    #expect(doc.definition().validate(value).isValid)
    #expect(throws: ParseAndValidateIssue.self) {
      try doc.parseAndValidate([
        "left": tree,
        "right": ["name": "bad", "children": [["name": 1, "children": []]]],
      ])
    }
    let arrays = try SchemaDocument { JSONArray { JSONReusable(DocumentTree.self) } }
    #expect(try arrays.parseAndValidate([tree]).count == 1)
    let union = try DocumentTreeChoice.document()
    #expect(try union.parseAndValidate(["second": ["_0": tree]]) == .second(parsed.left))
  }

  @Test func recursiveRootIsInlineAndClosureRootWorks() throws {
    let root = try DocumentTree.document()
    #expect(root.schemaValue["$dynamicAnchor"] != nil)
    #expect(root.schemaValue["$defs"]?.object?["Tree"] == nil)
    let value: JSONValue = ["name": "A", "children": [["name": "B", "children": []]]]
    #expect(try root.parseAndValidate(value).children.first?.name == "B")
    let modified = try SchemaDocument { DocumentTree.schema.title("Tree document") }
    #expect(try modified.parseAndValidate(value).children.first?.name == "B")
    let wrapped = try SchemaDocument { JSONReusable(DocumentTree.self) }
    #expect(try wrapped.parseAndValidate(value).children.first?.name == "B")
  }

  @Test func unsafeMacroModifiersAndTypeOptOutStayInline() throws {
    let doc = try DocumentModified.document()
    #expect(doc.schemaValue["$defs"] == nil)
    let value: JSONValue = [
      "address": ["street": "A"], "nullable": nil, "optedOut": ["street": "B"],
    ]
    #expect(try doc.parseAndValidate(value).nullable == nil)
    #expect(
      !doc.definition()
        .validate([
          "address": ["street": "A", "extra": true], "optedOut": ["street": "B"],
        ])
        .isValid
    )
  }

  @Test func staticSchemaProvidersAndCustomConversionsRemainCompatible() throws {
    let doc = try DocumentCompatibility.document()
    let value: JSONValue = ["inferred": "A", "customized": "B"]
    expectNoDifference(
      try doc.parseAndValidate(value),
      DocumentCompatibility(inferred: .init(value: "A"), customized: .init(value: "B"))
    )
    #expect(doc.schemaValue["properties"]?.object?["customized"]?.object?["$ref"] == nil)
    #expect(doc.schemaValue["properties"]?.object?["inferred"]?.object?["$ref"] != nil)
  }

  @Test func manualBuilderAndCachedComponents() throws {
    let cached = DocumentOrder.schema
    let inline = try SchemaDocument { cached }
    expectNoDifference(inline.schemaValue, cached.schemaValue)
    let document = try SchemaDocument {
      JSONObject {
        JSONProperty(key: "address") {
          JSONReusable(DocumentAddress.self).description("Home")
        }
      }
    }
    #expect(document.schemaValue["$defs"]?.object?["Address"] != nil)
    #expect(try document.parseAndValidate(["address": ["street": "A"]])?.street == "A")
  }

  @Test func conflictsAndUnsupportedUseSitesThrow() throws {
    #expect(throws: SchemaDocumentError.conflictingDefinition("Address")) {
      try SchemaDocument {
        JSONObject {
          JSONProperty(key: "first") { JSONReusable(DocumentAddress.self) }
          JSONProperty(key: "second") { JSONReusable(DocumentNameCollision.self) }
        }
      }
    }
    #expect(throws: SchemaDocumentError.self) {
      try SchemaDocument {
        JSONArray { JSONReusable(DocumentAddress.self).additionalProperties(false) }
      }
    }
    #expect(throws: SchemaDocumentError.self) {
      try SchemaDocument {
        JSONReusable(DocumentAddress.self).orNull(style: .type)
      }
    }
    let nullable = try SchemaDocument {
      JSONReusable(DocumentAddress.self).orNull(style: .union)
    }
    #expect(try nullable.parseAndValidate(.null) == nil)
    #expect(try nullable.parseAndValidate(["street": "A"])?.street == "A")
  }

  @Test func identifiersAndDuplicateInlineAnchorsThrow() {
    #expect(throws: SchemaDocumentError.unsupportedKeyword("$id")) {
      try SchemaDocument { DocumentOrder.schema.id("https://example.com/order") }
    }
    #expect(throws: SchemaDocumentError.self) {
      try SchemaDocument {
        JSONObject {
          JSONProperty(key: "first") { JSONReusable(DocumentTree.self, inline: true) }
          JSONProperty(key: "second") { JSONReusable(DocumentTree.self, inline: true) }
        }
      }
    }
  }

  @Test func independentConstructionIsDeterministic() async throws {
    let expected = try DocumentOrder.document().schemaValue
    try await withThrowingTaskGroup(of: SchemaValue.self) { group in
      for _ in 0 ..< 12 {
        group.addTask {
          let document = try DocumentOrder.document()
          _ = try document.parseAndValidate([
            "shipping": ["street": "A"], "billing": ["street": "B"],
          ])
          return document.schemaValue
        }
      }
      for try await value in group { expectNoDifference(value, expected) }
    }
  }

  @Test func buildOnceAndParseWithoutRebuilding() throws {
    enum Identity {}
    var builds = 0
    let doc = try SchemaDocument {
      JSONObject {
        JSONProperty(key: "first") {
          JSONReusable(Identity.self) {
            builds += 1
            return JSONString()
          }
        }
        JSONProperty(key: "second") {
          JSONReusable(Identity.self) {
            builds += 1
            return JSONString()
          }
        }
      }
    }
    #expect(builds == 1)
    _ = try doc.parseAndValidate(["first": "A", "second": "B"])
    _ = doc.parse(["first": "C", "second": "D"])
    #expect(builds == 1)
    #expect(!doc.schemaValue.value.description.contains("unknown_context"))
  }

  @Test func existingDefinitionCollisionsAndReferencesAreDiagnosed() {
    #expect(throws: SchemaDocumentError.conflictingDefinition("Address")) {
      try SchemaDocument {
        var component = JSONArray { JSONReusable(DocumentAddress.self) }
        component.schemaValue["$defs"] = ["Address": false]
        return component
      }
    }
    #expect(throws: SchemaDocumentError.unsupportedReference("#/$defs/missing")) {
      try SchemaDocument {
        JSONReference<DocumentAddress>.definition(named: "missing")
      }
    }
  }

  @Test func literalKeywordNamesAreNotTreatedAsSchemas() throws {
    let doc = try SchemaDocument {
      JSONString().default(["$id": "example", "$ref": "#/not-a-schema"])
    }
    #expect(doc.schemaValue["default"]?.object?["$ref"] != nil)
  }

  @Test func separatelyConstructedSchemasRemainInline() throws {
    let cached = DocumentTree.schema
    let doc = try SchemaDocument {
      JSONArray { cached }
    }
    let value: JSONValue = [
      ["name": "A", "children": [["name": "B", "children": []]]]
    ]
    #expect(try doc.parseAndValidate(value).first?.children.first?.name == "B")
  }

  @Test func documentEncodingRoundTrips() throws {
    let doc = try DocumentForest.document()
    let valid: JSONValue = [
      "left": ["name": "A", "children": []],
      "right": [
        "name": "B",
        "children": [
          ["name": "C", "children": [], "choice": ["first": ["_0": ["street": "A"]]]]
        ],
      ],
    ]
    let invalid: JSONValue = [
      "left": ["name": "A", "children": []],
      "right": ["name": "B", "children": [["name": 42, "children": []]]],
    ]
    let fixture: JSONValue = [
      "schema": doc.schemaValue.value, "valid": valid, "invalid": invalid,
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let decoded = try JSONValue.parse(String(decoding: encoder.encode(fixture), as: UTF8.self))
    expectNoDifference(decoded, fixture)
  }

  @Test func definitionNamesEscapePointersAndURIFragments() throws {
    let doc = try SchemaDocument { JSONArray { JSONReusable(DocumentEscapedName.self) } }
    #expect(doc.schemaValue["items"]?.object?["$ref"] == "#/$defs/Address~1with~0%20%23%25")
    #expect(try doc.parseAndValidate([["street": "A"]]).first?.street == "A")
  }

  @Test func equalSchemasWithDistinctGenericIdentitiesAreNotMerged() throws {
    enum Identity<T> {}
    let doc = try SchemaDocument {
      JSONObject {
        JSONProperty(key: "first") { JSONReusable(Identity<Int>.self) { JSONString() } }
        JSONProperty(key: "second") { JSONReusable(Identity<String>.self) { JSONString() } }
      }
    }
    #expect(doc.schemaValue["$defs"]?.object?.count == 2)
    let properties = try #require(doc.schemaValue["properties"]?.object)
    #expect(properties["first"]?.object?["$ref"] != properties["second"]?.object?["$ref"])
    let parsed = try doc.parseAndValidate(["first": "A", "second": "B"])
    #expect(parsed.0 == "A")
    #expect(parsed.1 == "B")
  }

  @Test func registeredManualReferencesUseTheFrozenParser() throws {
    let doc = try SchemaDocument {
      JSONObject {
        JSONProperty(key: "first") { JSONReusable(DocumentAddress.self) }
        JSONProperty(key: "second") {
          JSONReference<DocumentAddress>.definition(named: "Address")
        }
      }
    }
    let parsed = try doc.parseAndValidate([
      "first": ["street": "A"], "second": ["street": "B"],
    ])
    #expect(parsed.0?.street == "A")
    #expect(parsed.1?.street == "B")
  }

  @Test func unsupportedRecursiveVariantsAndMutualConstructionThrow() {
    #expect(throws: SchemaDocumentError.self) {
      try DocumentRecursiveInline.document()
    }
    #expect(throws: SchemaDocumentError.self) {
      try DocumentMutualA.document()
    }
  }

  @Test func nestedConstructionIsIsolated() throws {
    func attemptNestedDocument() -> JSONString {
      #expect(throws: SchemaDocumentError.nestedDocument) {
        try SchemaDocument { JSONString() }
      }
      return JSONString()
    }
    _ = try SchemaDocument { attemptNestedDocument() }
    #expect(try DocumentOrder.document().schemaValue["$defs"] != nil)
  }
}
