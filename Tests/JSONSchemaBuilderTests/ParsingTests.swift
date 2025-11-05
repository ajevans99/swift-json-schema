import JSONSchema
import JSONSchemaBuilder
import Testing

struct ParsingTests {
  @Schemable enum TestEmotion: String { case happy, sad, angry }
  @Schemable struct TestPerson {
    let emotions: [TestEmotion: Int]
    let analysisNotes: String
  }
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

    let match1 = try #require(result.value?.1.matches["x-custom"])
    #expect(match1.value == "abc")
    let match2 = try #require(result.value?.1.matches["x-extra"])
    #expect(match2.value == "def")
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

  @Test func propertyNamesCapture() throws {
    enum Emotion: String, CaseIterable { case happy, sad, angry }

    @JSONSchemaBuilder var sample: some JSONSchemaComponent<((), CapturedPropertyNames<Emotion>)> {
      JSONObject()
        .propertyNames {
          JSONString()
            .enumValues { Emotion.allCases.map(\.rawValue) }
            .compactMap { @Sendable value in Emotion.init(rawValue: value) }
        }
    }

    let input: JSONValue = [
      "happy": true,
      "sad": false,
    ]

    let result = sample.parse(input)

    switch result {
    case .valid((_, let names)):
      #expect(Set(names.seen) == Set([.happy, .sad]))
      #expect(Set(names.raw) == Set(["happy", "sad"]))
    default:
      #expect(Bool(false), "Expected valid parse result with propertyNames capture")
    }
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
    case .valid(((_, let patternResult), let additionalResult)):
      #expect(patternResult.matches.count == 2)
      #expect(additionalResult.matches.count == 1)
    default:
      #expect(
        Bool(false),
        "Expected valid parse result with both patternProperties and additionalProperties"
      )
    }
  }

  @Test func additionalPropertiesFalseValidation() throws {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent<Void> {
      JSONObject()
        .additionalProperties(false)
    }

    let input: JSONValue = ["extra": true]

    let result = sample.parse(input)
    #expect(result.value != nil)

    #expect(throws: ParseAndValidateIssue.self) {
      _ = try sample.parseAndValidate(instance: "{\"extra\": true}")
    }
  }

  @Test func dictionaryWithEnumKeysParsing() throws {
    let input: JSONValue = [
      "emotions": ["happy": 1, "sad": 2],
      "analysisNotes": "hi",
    ]

    let result = TestPerson.schema.parse(input)
    let person = try #require(result.value)
    #expect(person.emotions[.happy] == 1)
    #expect(person.emotions[.sad] == 2)
    #expect(person.analysisNotes == "hi")
  }
}
