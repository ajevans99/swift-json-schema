import InlineSnapshotTesting
import JSONSchemaBuilder
import Testing

@Schemable(keyStrategy: .snakeCase)
struct SnakePerson {
  let firstName: String
  let lastName: String
}

@Schemable
struct CustomKeyPerson {
  @SchemaOptions(.key("first_name"))
  let firstName: String
  let lastName: String
}

struct KeyEncodingTests {
  @Test(.snapshots(record: false)) func snakeCase() {
    let schema = SnakePerson.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "first_name" : {
            "type" : "string"
          },
          "last_name" : {
            "type" : "string"
          }
        },
        "required" : [
          "first_name",
          "last_name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func override() {
    let schema = CustomKeyPerson.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "first_name" : {
            "type" : "string"
          },
          "lastName" : {
            "type" : "string"
          }
        },
        "required" : [
          "first_name",
          "lastName"
        ],
        "type" : "object"
      }
      """#
    }
  }
}
