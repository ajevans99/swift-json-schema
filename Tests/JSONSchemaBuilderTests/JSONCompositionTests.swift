import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONCompositionTests {
  @Test func anyOfComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AnyOf {
        JSONString()
        JSONNumber().minimum(0)
      }
    }

    let expected: [String: JSONValue] = [
      "anyOf": [
        ["type": "string"],
        ["type": "number", "minimum": 0]
      ]
    ]

    #expect(sample.schemaValue == expected)
  }

  @Test func allOfComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        JSONString()
        JSONNumber().maximum(10)
      }
    }

    let expected: [String: JSONValue] = [
      "allOf": [
        ["type": "string"],
        ["type": "number", "maximum": 10]
      ]
    ]

    #expect(sample.schemaValue == expected)
  }

  @Test func oneOfComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.OneOf {
        JSONString().pattern("^[a-zA-Z]+$")
        JSONBoolean()
      }
    }

    let expected: [String: JSONValue] = [
      "oneOf": [
        ["type": "string", "pattern": "^[a-zA-Z]+$"],
        ["type": "boolean"]
      ]
    ]

    #expect(sample.schemaValue == expected)
  }

  @Test func notComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.Not { JSONString() }
    }

    let expected: [String: JSONValue] = [
      "not": ["type": "string"]
    ]

    #expect(sample.schemaValue == expected)
  }

  @Test func annotations() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        JSONString()
        JSONNumber().maximum(10)
      }
      .title("Item")
      .description("This is the description")
    }

    let expected: [String: JSONValue] = [
      "title": "Item",
      "description": "This is the description",
      "allOf": [
        ["type": "string"],
        ["type": "number", "maximum": 10]
      ]
    ]

    #expect(sample.schemaValue == expected)
  }
}
