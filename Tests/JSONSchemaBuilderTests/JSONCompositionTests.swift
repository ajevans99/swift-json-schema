import JSONSchema
import JSONSchemaBuilder
import Testing

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
        ["type": "number", "minimum": 0],
      ]
    ]

    #expect(sample.schemaValue == .object(expected))
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
        ["type": "number", "maximum": 10],
      ]
    ]

    #expect(sample.schemaValue == .object(expected))
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
        ["type": "boolean"],
      ]
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func notComposition() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.Not { JSONString() }
    }

    let expected: [String: JSONValue] = [
      "not": ["type": "string"]
    ]

    #expect(sample.schemaValue == .object(expected))
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
        ["type": "number", "maximum": 10],
      ],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func forLoop() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        for i in 0..<10 {
          JSONString()
            .title("\(i)")
        }
      }
    }

    #expect(sample.schemaValue.object?[Keywords.AllOf.name]?.array?.count == 10)
  }

  @Test(arguments: [true, false]) func `if`(bool: Bool) {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONComposition.AllOf {
        if bool {
          JSONString()
            .title("0")
        }
      }
    }

    #expect(
      sample.schemaValue.object?[Keywords.AllOf.name]?.array?.count == (bool ? 1 : 0)
    )
  }
}
