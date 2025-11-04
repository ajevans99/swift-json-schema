import InlineSnapshotTesting
import JSONSchemaBuilder
import Testing

@Schemable
struct PersonWithCodingKeys {
  let firstName: String
  let lastName: String
  let emailAddress: String

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case emailAddress = "email"
  }
}

@Schemable
struct PersonWithPartialCodingKeys {
  let firstName: String
  let middleName: String
  let lastName: String

  enum CodingKeys: String, CodingKey {
    case firstName = "given_name"
    case middleName
    case lastName = "family_name"
  }
}

@Schemable
struct PersonWithCodingKeysAndOverride {
  let firstName: String
  @SchemaOptions(.key("surname"))
  let lastName: String

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
  }
}

struct CodingKeysIntegrationTests {
  @Test(.snapshots(record: false)) func codingKeys() {
    let schema = PersonWithCodingKeys.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "email" : {
            "type" : "string"
          },
          "first_name" : {
            "type" : "string"
          },
          "last_name" : {
            "type" : "string"
          }
        },
        "required" : [
          "first_name",
          "last_name",
          "email"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func partialCodingKeys() {
    let schema = PersonWithPartialCodingKeys.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "family_name" : {
            "type" : "string"
          },
          "given_name" : {
            "type" : "string"
          },
          "middleName" : {
            "type" : "string"
          }
        },
        "required" : [
          "given_name",
          "middleName",
          "family_name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func codingKeysWithOverride() {
    let schema = PersonWithCodingKeysAndOverride.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "first_name" : {
            "type" : "string"
          },
          "surname" : {
            "type" : "string"
          }
        },
        "required" : [
          "first_name",
          "surname"
        ],
        "type" : "object"
      }
      """#
    }
  }
}
