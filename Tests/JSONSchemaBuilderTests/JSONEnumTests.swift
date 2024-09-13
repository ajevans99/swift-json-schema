import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONEnumTests {
  @Test func singleValue() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent { JSONString().enumValues { "red" } }
    #expect(sample.definition.enumValues == ["red"])
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
    #expect(sample.definition.enumValues == ["red", "amber", "green"])
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

    #expect(sample.definition.enumValues == ["red", "amber", "green", nil, 42])
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
    #expect(sample.annotations.title == "Color")
  }
}
