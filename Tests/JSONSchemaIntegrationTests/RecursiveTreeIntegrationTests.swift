import JSONSchema
import JSONSchemaBuilder
import SnapshotTesting
import Testing

@Schemable
struct TreeNode: Sendable, Equatable {
  let name: String
  let children: [TreeNode]
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
}
