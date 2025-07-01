import InlineSnapshotTesting
import JSONSchema
import JSONSchemaBuilder
import Testing

struct CreditInfo: Equatable {
  let creditCard: Int?
  let billingAddress: String?

  static var schema: some JSONSchemaComponent<CreditInfo> {
    JSONSchema(CreditInfo.init) {
      JSONObject {
        JSONProperty(key: "credit_card") { JSONInteger() }
        JSONProperty(key: "billing_address") { JSONString() }
      }
      .dependentRequired(["credit_card": ["billing_address"]])
    }
  }
}

struct NameConditional {
  static var schema: some JSONSchemaComponent<JSONValue> {
    If(
      { JSONString().minLength(1) },
      then: { JSONString().pattern("^foo") },
      else: { JSONString().pattern("^bar") }
    )
  }
}

struct ConditionalTests {
  @Test(.snapshots(record: false))
  func schema() {
    let schema = CreditInfo.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "dependentRequired" : {
          "credit_card" : [
            "billing_address"
          ]
        },
        "properties" : {
          "billing_address" : {
            "type" : "string"
          },
          "credit_card" : {
            "type" : "integer"
          }
        },
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false))
  func dslSchema() {
    let schema = NameConditional.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "else" : {
          "pattern" : "^bar",
          "type" : "string"
        },
        "if" : {
          "minLength" : 1,
          "type" : "string"
        },
        "then" : {
          "pattern" : "^foo",
          "type" : "string"
        }
      }
      """#
    }
  }

  @Test(arguments: [
    (
      JSONValue.object(["credit_card": .integer(1234), "billing_address": .string("123 St")]), true
    ),
    (JSONValue.object(["credit_card": .integer(1234)]), false),
    (JSONValue.object(["billing_address": .string("123 St")]), true),
  ])
  func validate(instance: JSONValue, isValid: Bool) {
    let schema = CreditInfo.schema.definition()
    let result = schema.validate(instance)
    #expect(result.isValid == isValid)
  }
}
