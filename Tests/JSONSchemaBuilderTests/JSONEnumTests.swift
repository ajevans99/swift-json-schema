import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct JSONEnumTests {
  @Test func sameType() {
    @JSONSchemaBuilder var sample: JSONSchemaComponent {
      JSONEnum {
        "red"
        "amber"
        "green"
      }
    }
    #expect(sample.definition.enumValues == ["red", "amber", "green"])
  }

  @Test func differentType() {
    @JSONSchemaBuilder var sample: JSONSchemaComponent {
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
    @JSONSchemaBuilder var sample: JSONSchemaComponent {
      JSONEnum(values: ["red", "amber", "green"])
    }
    #expect(sample.definition.enumValues == ["red", "amber", "green"])
  }
}
