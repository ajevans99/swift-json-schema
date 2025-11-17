import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct WrapperTests {
  @Test func optionalComponent() {
    let opt = JSONComponents.OptionalComponent<JSONString>(wrapped: nil)
    let result = opt.parse(.string("hi"))
    switch result {
    case .valid(let value):
      #expect(value == nil)
    default:
      Issue.record("expected valid result")
    }
  }

  @Test func erasedComponent() {
    let any = JSONString().eraseToAnySchemaComponent()
    #expect(any.schemaValue == JSONString().schemaValue)
  }

  @Test func passthrough() {
    let passthrough = JSONComponents.PassthroughComponent(wrapped: JSONString())
    let result = passthrough.parse(.string("hi"))
    #expect(result.value == .string("hi"))
  }

  @Test func runtimeComponent() throws {
    let raw: JSONValue = ["type": "string"]
    let runtime = try RuntimeComponent(rawSchema: raw)
    #expect(runtime.parse(.string("abc")).value == .string("abc"))
  }

  @Test func anyValueInit() {
    let any = JSONAnyValue(JSONString())
    #expect(any.schemaValue.object?[Keywords.TypeKeyword.name] == .string("string"))
  }

  @Test func jsonValueSchemaPassesThroughInput() {
    let schema = JSONValue.schema
    let input: JSONValue = [
      "message": "hi",
      "numbers": [1, 2, 3],
      "nested": [
        "flag": true
      ],
    ]

    #expect(schema.parse(input).value == input)
  }

  @Test func jsonValueInObjectSchema() {
    struct Update: Equatable {
      let path: String
      let value: JSONValue
      let meta: [String: JSONValue]
    }

    let schema = JSONSchema(Update.init) {
      JSONObject {
        JSONProperty(key: "path") {
          JSONString()
        }
        .required()
        JSONProperty(key: "value") {
          JSONValue.schema
        }
        .required()
        JSONProperty(key: "meta") {
          JSONObject()
            .additionalProperties {
              JSONValue.schema
            }
            .map(\.1)
            .map(\.matches)
        }
        .required()
      }
    }

    let input: JSONValue = [
      "path": "config.value",
      "value": [
        "operation": "replace",
        "data": ["count": 2],
      ],
      "meta": [
        "attempts": 1,
        "confirmed": true,
      ],
    ]

    let expected = Update(
      path: "config.value",
      value: [
        "operation": "replace",
        "data": ["count": 2],
      ],
      meta: [
        "attempts": 1,
        "confirmed": true,
      ]
    )

    #expect(schema.parse(input).value == expected)
  }
}
