import JSONSchema
import JSONSchemaBuilder
import Testing

private enum PlanningFixtures {
  @Schemable
  struct Leaf {
    let name: String
  }

  @Schemable
  struct Box<Value: Schemable> where Value.Schema.Output == Value {
    let value: Value
  }

  @Schemable
  struct Container {
    let label: Swift.Optional<String>
    let values: Swift.Array<Int>
    let metadata: Swift.Dictionary<String, String>
    let nested: Box<Leaf>
  }

  @Schemable
  final class Record {
    let name: String

    init(name: String) {
      self.name = name
    }
  }

  @Schemable
  struct Token {
    let value: Int

    init(value: Int) {
      self.value = value
    }

    init(value: String) {
      self.value = Int(value) ?? 0
    }
  }

  @Schemable
  struct TokenWithMatchingInitializerLast {
    let value: Int

    init(value: String) {
      self.value = Int(value) ?? 0
    }

    init(value: Int) {
      self.value = value
    }
  }

  @Schemable
  struct RecordWithReorderedInitializerFirst {
    let name: String
    let count: Int

    init(count: Int, name: String) {
      self.name = name
      self.count = count
    }

    init(name: String, count: Int) {
      self.name = name
      self.count = count
    }
  }

  @Schemable
  enum Event {
    case message(String, count: Swift.Optional<Int>)
  }

  @Schemable
  enum EscapedValue: String {
    case quote = #"a"b"#
    case slash = #"a\b"#
  }

  @Schemable
  struct EscapedKey {
    /// Contains """# and \#(literal) without ending the generated string.
    let `default`: String

    enum CodingKeys: String {
      case `default` = #"name"key"#
    }
  }

  struct ReplacementString: Schemable {
    static var schema: JSONString {
      JSONString()
    }
  }

  struct ReplacementObject: Schemable {
    static var schema: some JSONSchemaComponent<String> {
      JSONObject {
        JSONProperty(key: "replacement") { JSONString() }
          .required()
      }
    }
  }

  @Schemable
  struct ReplacedProperty {
    @StringOptions(.minLength(2))
    @SchemaOptions(.customSchema(ReplacementString.self), .description("kept"))
    @StringOptions(.maxLength(4))
    @SchemaOptions(.title("last"))
    let value: String
  }

  @Schemable
  @ObjectOptions(.minProperties(2))
  @SchemaOptions(.customSchema(ReplacementObject.self), .description("kept"))
  @ObjectOptions(.maxProperties(2))
  @SchemaOptions(.title("last"))
  struct ReplacedObject {
    let value: String
  }

  @Schemable(keyStrategy: nil)
  struct IdentityKeys {
    let firstName: String
  }
}

@Schemable
private struct PrivatePlanningFixture {
  let name: String
}

struct MacroPlanningIntegrationTests {
  @Test func normalizedBuiltinsAndNamedGenericsCompileAndParse() throws {
    let result = try PlanningFixtures.Container.schema.parse(
      instance: """
        {
          "label": null,
          "values": [1, 2],
          "metadata": {"key": "value"},
          "nested": {"value": {"name": "leaf"}}
        }
        """
    )
    let value = try #require(result.value)
    #expect(value.label == nil)
    #expect(value.values == [1, 2])
    #expect(value.metadata == ["key": "value"])
    #expect(value.nested.value.name == "leaf")
  }

  @Test func classUsesExplicitInitializerWithoutCopyingFinalModifier() throws {
    let result = try PlanningFixtures.Record.schema.parse(instance: #"{"name":"example"}"#)
    #expect(result.value?.name == "example")
  }

  @Test func matchingInitializerOverloadCompilesAndParsesInteger() throws {
    let schema = PlanningFixtures.Token.schema
    let expected: JSONValue = [
      "type": "object",
      "properties": ["value": ["type": "integer"]],
      "required": ["value"],
    ]
    #expect(schema.schemaValue.value == expected)

    let result = try schema.parse(instance: #"{"value":42}"#)
    let token = try #require(result.value)
    #expect(token.value == 42)
    #expect(result.errors == nil)
  }

  @Test func laterMatchingInitializerOverloadCompilesAndParsesInteger() throws {
    let schema = PlanningFixtures.TokenWithMatchingInitializerLast.schema
    let expected: JSONValue = [
      "type": "object",
      "properties": ["value": ["type": "integer"]],
      "required": ["value"],
    ]
    #expect(schema.schemaValue.value == expected)

    let result = try schema.parse(instance: #"{"value":42}"#)
    let token = try #require(result.value)
    #expect(token.value == 42)
    #expect(result.errors == nil)
  }

  @Test func reorderedInitializerDoesNotHideLaterCompatibleOverload() throws {
    let schema = PlanningFixtures.RecordWithReorderedInitializerFirst.schema
    let result = try schema.parse(instance: #"{"name":"example","count":42}"#)
    let record = try #require(result.value)
    #expect(record.name == "example")
    #expect(record.count == 42)
    #expect(result.errors == nil)
  }

  @Test func privateDeclarationConformanceCompilesAndParses() throws {
    let result = try PrivatePlanningFixture.schema.parse(instance: #"{"name":"private"}"#)
    #expect(result.value?.name == "private")
  }

  @Test func enumPayloadUsesSameFieldAndConstructorOrder() throws {
    let result = try PlanningFixtures.Event.schema.parse(
      instance: #"{"message":{"_0":"hello","count":3}}"#
    )
    guard case .message(let text, let count) = try #require(result.value) else {
      Issue.record("Expected message")
      return
    }
    #expect(text == "hello")
    #expect(count == 3)
  }

  @Test func escapedCodingKeyAndDocumentationRetainTheirValues() throws {
    let result = try PlanningFixtures.EscapedKey.schema.parse(
      instance: #"{"name\"key":"value"}"#
    )
    #expect(result.value?.default == "value")
    let description = PlanningFixtures.EscapedKey.schema.schemaValue["properties"]?
      .object?["name\"key"]?
      .object?["description"]?
      .string
    #expect(description == ##"Contains """# and \#(literal) without ending the generated string."##)
  }

  @Test func escapedEnumValuesCompileAndParse() throws {
    let quote = try PlanningFixtures.EscapedValue.schema.parse(instance: #""a\"b""#)
    let slash = try PlanningFixtures.EscapedValue.schema.parse(instance: #""a\\b""#)
    #expect(quote.value == .quote)
    #expect(slash.value == .slash)
  }

  @Test func propertyReplacementDiscardsEarlierConstraintsAndKeepsLaterOnes() throws {
    let schema = PlanningFixtures.ReplacedProperty.schema
    let expected: JSONValue = [
      "type": "object",
      "properties": [
        "value": [
          "type": "string",
          "description": "kept",
          "maxLength": 4,
          "title": "last",
        ]
      ],
      "required": ["value"],
    ]
    #expect(schema.schemaValue.value == expected)

    #expect(try schema.parseAndValidate(instance: #"{"value":"x"}"#).value == "x")
    #expect(try schema.parseAndValidate(instance: #"{"value":"abcd"}"#).value == "abcd")
    #expect(throws: ParseAndValidateIssue.self) {
      try schema.parseAndValidate(instance: #"{"value":"abcde"}"#)
    }
  }

  @Test func declarationReplacementDiscardsEarlierConstraintsAndKeepsLaterOnes() throws {
    let schema = PlanningFixtures.ReplacedObject.schema
    let expected: JSONValue = [
      "type": "object",
      "properties": ["replacement": ["type": "string"]],
      "required": ["replacement"],
      "description": "kept",
      "maxProperties": 2,
      "title": "last",
    ]
    #expect(schema.schemaValue.value == expected)

    #expect(try schema.parseAndValidate(instance: #"{"replacement":"x"}"#).value == "x")
    #expect(
      try schema.parseAndValidate(instance: #"{"replacement":"x","extra":true}"#).value == "x"
    )
    #expect(throws: ParseAndValidateIssue.self) {
      try schema.parseAndValidate(instance: #"{"replacement":"x","extra":true,"another":false}"#)
    }
  }

  @Test func explicitNilKeyStrategyCompilesAndUsesPropertyNames() throws {
    let schema = PlanningFixtures.IdentityKeys.schema
    let expected: JSONValue = [
      "type": "object",
      "properties": ["firstName": ["type": "string"]],
      "required": ["firstName"],
    ]
    #expect(schema.schemaValue.value == expected)
    let result = try schema.parse(instance: #"{"firstName":"Taylor"}"#)
    #expect(result.value?.firstName == "Taylor")
    #expect(result.errors == nil)
  }
}
