import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONEnumTests {
  @Test func singleValue() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent { JSONEnum { "red" } }
    #expect(sample.definition.enumValues == ["red"])
  }

  @Test func sameType() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONEnum {
        "red"
        "amber"
        "green"
      }
    }
    #expect(sample.definition.enumValues == ["red", "amber", "green"])
  }

  @Test func differentType() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONEnum {
        "red"
        "amber"
        "green"
        nil
        42
      }
    }

    #expect(sample.definition.enumValues == ["red", "amber", "green", nil, 42])
  }

  @Test func withoutBuilder() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONEnum(cases: ["red", "amber", "green"])
    }
    #expect(sample.definition.enumValues == ["red", "amber", "green"])
  }

  @Test func annotations() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONEnum {
        "red"
        "amber"
        "green"
      }
      .title("Color")
    }
    print(sample.annotations)
    #expect(sample.annotations.title == "Color")
  }
}
