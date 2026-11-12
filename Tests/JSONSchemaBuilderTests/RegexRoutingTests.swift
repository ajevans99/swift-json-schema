import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct RegexRoutingTests {
  @Test(arguments: [
    ("^.$", "e\u{301}", false),
    ("^\u{e9}$", "e\u{301}", false),
    ("^\u{e9}$", "\u{e9}", true),
    (#"^\d$"#, "\u{661}", false),
    (#"^\w$"#, "\u{e9}", false),
    (#"^\w$"#, "_", true),
    (#"^\s$"#, "\u{a0}", true),
  ])
  func propertyAndAdditionalParsersUseTheValidatorPolicy(
    pattern: String,
    key: String,
    matches: Bool
  ) throws {
    let schema = JSONObject()
      .patternProperties {
        JSONProperty(key: pattern) { JSONInteger() }
      }
      .additionalProperties { JSONString() }
    let value: JSONValue = .object([key: matches ? 1 : "additional"])
    let output = try schema.parseAndValidate(value)
    #expect((output.0.1.matches[key] != nil) == matches)
    #expect((output.1.matches[key] != nil) == !matches)
  }

  @Test func invalidPatternsProduceParseIssues() {
    let schema = JSONObject()
      .patternProperties {
        JSONProperty(key: "[") { JSONInteger() }
      }
    guard case .invalid(let issues) = schema.parse(["x": 1]) else {
      Issue.record("Invalid regular expressions must not be silently skipped")
      return
    }
    #expect(!issues.isEmpty)
  }
}
