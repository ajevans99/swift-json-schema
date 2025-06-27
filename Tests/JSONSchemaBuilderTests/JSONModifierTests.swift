import JSONSchema
import JSONSchemaBuilder
import Testing

struct JSONEnumTests {
  @Test func singleValue() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .enumValues { "red" }
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "enum": ["red"],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func sameType() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .enumValues {
          "red"
          "amber"
          "green"
        }
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "enum": ["red", "amber", "green"],
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func differentType() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONAnyValue()
        .enumValues {
          "red"
          "amber"
          "green"
          nil
          42
        }
    }

    let expected: [String: JSONValue] = [
      "enum": ["red", "amber", "green", nil, 42]
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func annotations() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .enumValues {
          "red"
          "amber"
          "green"
        }
        .title("Color")
    }

    let expected: [String: JSONValue] = [
      "title": "Color",
      "type": "string",
      "enum": ["red", "amber", "green"],
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}

struct JSONConstantTests {
  @Test func constantOnly() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONAnyValue()
        .constant("red")
    }

    let expected: [String: JSONValue] = [
      "const": "red"
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func string() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .constant("red")
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "const": "red",
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}
