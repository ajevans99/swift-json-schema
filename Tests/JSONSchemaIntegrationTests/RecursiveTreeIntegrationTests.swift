import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
struct TreeNode: Sendable, Equatable {
  let name: String
  let children: [TreeNode]
}

struct RecursiveTreeIntegrationTests {
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

    #expect(schema.validate(invalid).isValid == false)
  }
}
