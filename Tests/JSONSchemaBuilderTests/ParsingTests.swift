import JSONSchema
import JSONSchemaBuilder
import Testing

struct ParsingTests {
  @Test func patternProperties() throws {
    @JSONSchemaBuilder var sample:
      some JSONSchemaComponent<((), PatternPropertiesParseResult<String?>)>
    {
      JSONObject()
        .patternProperties {
          JSONProperty(key: "^x-") { JSONString() }
        }
    }

    let input: JSONValue = [
      "x-custom": "abc",
      "x-extra": "def",
      "other": 123,
    ]

    let result = sample.parse(input)

    #expect(result.value?.1.matches["^x-"]?.count == 2)
  }

  @Test func additionalPropertiesValidation() throws {
    @JSONSchemaBuilder var sample:
      some JSONSchemaComponent<((), AdditionalPropertiesParseResult<Bool>)>
    {
      JSONObject()
        .additionalProperties { JSONBoolean() }
    }

    let input: JSONValue = [
      "extra1": true,
      "extra2": false,
      "extra3": true,
    ]

    let result = sample.parse(input)

    #expect(result.value?.1.matches.count == 3)
  }

  @Test func patternAndAdditionalProperties() throws {
    @JSONSchemaBuilder var sample:
      some JSONSchemaComponent<
        (((), PatternPropertiesParseResult<String?>), AdditionalPropertiesParseResult<Bool>)
      >
    {
      JSONObject()
        .patternProperties {
          JSONProperty(key: "^x-") { JSONString() }
        }
        .additionalProperties { JSONBoolean() }
    }

    let input: JSONValue = [
      "x-custom": "abc",
      "x-extra": "def",
      "other": true,
    ]

    let result = sample.parse(input)

    switch result {
    case .valid(let ((_, patternResult), additionalResult)):
      #expect(patternResult.matches["^x-"]?.count == 2)
      #expect(additionalResult.matches.count == 1)
    default:
      #expect(
        Bool(false),
        "Expected valid parse result with both patternProperties and additionalProperties"
      )
    }
  }
}
