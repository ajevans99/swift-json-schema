import JSONSchema
import JSONSchemaBuilder
import Testing

struct JSONEmptyPropertyNameTests {
  @Test func emptyPropertyIsEmittedValidatedAndAnnotated() throws {
    let schema = JSONObject {
      JSONProperty(key: "") { JSONInteger() }.required()
      JSONProperty(key: "a") { JSONString() }.required()
    }
    .additionalProperties(false)
    #expect(schema.schemaValue["properties"] == ["": ["type": "integer"], "a": ["type": "string"]])
    #expect(schema.schemaValue["required"] == ["", "a"])

    let input: JSONValue = ["": 42, "a": "hello"]
    let result = schema.definition().validate(input)
    #expect(result.isValid)
    let annotation = try #require(result.annotations?.first { $0.keyword == "properties" })
    #expect(Set(annotation.jsonValue.array ?? []) == Set([.string(""), .string("a")]))
    let output = try schema.parseAndValidate(input)
    #expect(output.0 == 42)
    #expect(output.1 == "hello")

    #expect(!schema.definition().validate(["a": "hello"]).isValid)
    #expect(!schema.definition().validate(["": "wrong", "a": "hello"]).isValid)
    #expect(!schema.definition().validate(["": 42, "a": "hello", "extra": true]).isValid)
  }

  @Test func optionalEmptyPropertyAndTypedExtrasRemainDistinct() throws {
    let schema = JSONObject {
      JSONProperty(key: "", value: JSONInteger())
    }
    .additionalProperties { JSONString() }
    #expect(schema.schemaValue["properties"] == ["": ["type": "integer"]])
    let present = try schema.parseAndValidate(["": 42, "other": "hello"])
    #expect(present.0 == 42)
    #expect(present.1.matches == ["other": "hello"])
    let absent = try schema.parseAndValidate(["other": "hello"])
    #expect(absent.0 == nil)
    #expect(absent.1.matches == ["other": "hello"])
  }

  @Test func emptyBuilderAbsentConditionalAndEmptyLoopDoNotEmitAProperty() {
    let empty = JSONObject {}
    let includeProperty = false
    let conditional = JSONObject {
      if includeProperty {
        JSONProperty(key: "") { JSONInteger() }.required()
      }
    }
    let names: [String] = []
    let loop = JSONObject {
      for name in names {
        JSONProperty(key: name) { JSONInteger() }.required()
      }
    }
    #expect(empty.schemaValue == ["type": "object"])
    #expect(conditional.schemaValue == empty.schemaValue)
    #expect(loop.schemaValue == empty.schemaValue)
    #expect(empty.additionalProperties(false).definition().validate([:]).isValid)
    #expect(!conditional.additionalProperties(false).definition().validate(["": 42]).isValid)
    #expect(!loop.additionalProperties(false).definition().validate(["": 42]).isValid)
  }

  @Test func emptyPatternIsEmittedAndMatchesEveryPropertyName() throws {
    let schema = JSONObject()
      .patternProperties { JSONProperty(key: "") { JSONString() } }
      .additionalProperties(false)
    #expect(schema.schemaValue["patternProperties"] == ["": ["type": "string"]])
    let result = try schema.parseAndValidate(["": "empty", "named": "value"])
    #expect(result.1.matches[""]?.value == "empty")
    #expect(result.1.matches["named"]?.value == "value")
    #expect(!schema.definition().validate(["named": 42]).isValid)
  }
}
