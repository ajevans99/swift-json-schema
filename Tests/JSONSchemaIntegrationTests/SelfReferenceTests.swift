import InlineSnapshotTesting
import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
struct Node {
  var children: [Node]
}

struct SelfReferenceTests {
  @Test(.snapshots(record: false))
  func schema() {
    let schema = Node.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "$anchor" : "Node",
        "properties" : {
          "children" : {
            "items" : {
              "$ref" : "#Node"
            },
            "type" : "array"
          }
        },
        "required" : [
          "children"
        ],
        "type" : "object"
      }
      """#
    }
  }
}
