import JSONSchema
import JSONSchemaBuilder
import SnapshotTesting
import Testing

@Schemable
struct TreeNode: Sendable, Equatable {
  let name: String
  let children: [TreeNode]
}

@Schemable
struct RecursiveDocumentPair: Equatable {
  let left: TreeNode
  let right: TreeNode
}

@Schemable
struct RecursiveDocumentLists: Equatable {
  let left: [TreeNode]
  let right: [TreeNode]
}

@Schemable
enum RecursiveDocumentUnion: Equatable {
  case left(TreeNode)
  case right(TreeNode)
}

struct RecursiveTreeIntegrationTests {
  // Schema definition for a recursive type — locks in the `$defs` /
  // `$ref` shape so accidental regressions in how recursive Schemables
  // emit (or stop emitting) recursion get caught at PR time. Regular
  // snapshot because this output is large and changing it warrants
  // careful review.
  @Test func treeSchemaDefinition() throws {
    assertSnapshot(of: TreeNode.schema.definition(), as: .json)
  }

  @Test func treeSchemaValidatesRecursiveDocuments() throws {
    let schema = TreeNode.schema.definition()

    let valid: JSONValue = [
      "name": "root",
      "children": [
        ["name": "child", "children": []],
        [
          "name": "branch",
          "children": [
            ["name": "leaf", "children": []]
          ],
        ],
      ],
    ]

    #expect(schema.validate(valid).isValid)
  }

  @Test func treeSchemaInvalidRecursiveDocuments() throws {
    let schema = TreeNode.schema.definition()

    let invalid: JSONValue = [
      "name": "root",
      "children": [
        [
          "name": "branch",
          "children": [
            ["name": 42, "children": []]
          ],
        ]
      ],
    ]

    let result = schema.validate(invalid)
    #expect(result.isValid == false)
    // Lock in the actual error tree for the deepest failure — proves we
    // don't just say "invalid" but pinpoint that the `name` at
    // /children/0/children/0/name is the wrong type.
    assertSnapshot(of: result, as: .json)
  }

  @Test func documentBundlesRepeatedRecursivePropertiesAndPreservesTypedParsing() throws {
    let document = try RecursiveDocumentPair.schema.document()
    let anchor = TreeNode.defaultAnchor

    #expect(
      document.value.value(at: .init(tokens: ["properties", "left", "$ref"]))
        == .string("#/$defs/\(anchor)")
    )
    #expect(
      document.value.value(at: .init(tokens: ["properties", "right", "$ref"]))
        == .string("#/$defs/\(anchor)")
    )
    #expect(
      document.value.value(at: .init(tokens: ["$defs", anchor, "$dynamicAnchor"]))
        == .string(anchor)
    )

    let schema = try Schema(rawSchema: document.value, context: .init(dialect: .draft2020_12))
    let valid: JSONValue = [
      "left": ["name": "left", "children": []],
      "right": ["name": "right", "children": [["name": "child", "children": []]]],
    ]
    let invalid: JSONValue = [
      "left": ["name": "left", "children": []],
      "right": ["name": "right", "children": [["name": 1, "children": []]]],
    ]

    #expect(schema.validate(valid).isValid)
    #expect(!schema.validate(invalid).isValid)
    #expect(try RecursiveDocumentPair.schema.parseAndValidate(valid) == RecursiveDocumentPair(
      left: TreeNode(name: "left", children: []),
      right: TreeNode(name: "right", children: [TreeNode(name: "child", children: [])]
      )
    ))
  }

  @Test func documentBundlesRepeatedRecursiveArraysAndUnionBranches() throws {
    try assertDocumentBundles(RecursiveDocumentLists.schema)
    try assertDocumentBundles(RecursiveDocumentUnion.schema)
  }

  private func assertDocumentBundles<Component: JSONSchemaComponent>(
    _ component: Component
  ) throws {
    let document = try component.document()
    let anchor = TreeNode.defaultAnchor

    #expect(
      document.value.value(at: .init(tokens: ["$defs", anchor, "$dynamicAnchor"]))
        == .string(anchor)
    )
    #expect(dynamicAnchorCount(in: document.value, named: anchor) == 1)
  }

  private func dynamicAnchorCount(in value: JSONValue, named anchor: String) -> Int {
    switch value {
    case .object(let object):
      return (object["$dynamicAnchor"] == .string(anchor) ? 1 : 0)
        + object.values.reduce(0) { $0 + dynamicAnchorCount(in: $1, named: anchor) }
    case .array(let values):
      return values.reduce(0) { $0 + dynamicAnchorCount(in: $1, named: anchor) }
    default:
      return 0
    }
  }
}
