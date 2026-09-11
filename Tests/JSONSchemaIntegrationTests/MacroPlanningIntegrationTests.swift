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
}
