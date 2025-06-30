import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONConditionalBuilderTests {
  @Test func ifThenElse() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .`if` { JSONString().minLength(1) }
        .then { JSONString().pattern("^foo") }
        .`else` { JSONString().pattern("^bar") }
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "if": ["type": "string", "minLength": 1],
      "then": ["type": "string", "pattern": "^foo"],
      "else": ["type": "string", "pattern": "^bar"],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func dependentRequired() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONObject {
        JSONProperty(key: "a") { JSONInteger() }
        JSONProperty(key: "b") { JSONInteger() }
      }
      .dependentRequired(["a": ["b"]])
    }

    let expected: [String: JSONValue] = [
      "type": "object",
      "properties": [
        "a": ["type": "integer"],
        "b": ["type": "integer"],
      ],
      "dependentRequired": ["a": ["b"]],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func dependentSchemas() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONObject {
        JSONProperty(key: "credit_card") { JSONInteger() }
        JSONProperty(key: "billing_address") { JSONString() }
      }
      .dependentSchemas([
        "credit_card": JSONObject {
          JSONProperty(key: "billing_address") { JSONString() }.required()
        }
      ])
    }

    let expected: [String: JSONValue] = [
      "type": "object",
      "properties": [
        "credit_card": ["type": "integer"],
        "billing_address": ["type": "string"],
      ],
      "dependentSchemas": [
        "credit_card": [
          "type": "object",
          "properties": [
            "billing_address": ["type": "string"]
          ],
          "required": ["billing_address"],
        ]
      ],
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}
