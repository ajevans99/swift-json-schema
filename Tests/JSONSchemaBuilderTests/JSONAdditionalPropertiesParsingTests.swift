import JSONSchema
import JSONSchemaBuilder
import Testing

private struct EmptyAdditionalFailure: JSONSchemaComponent {
  var schemaValue = JSONString().schemaValue
  func parse(_ value: JSONValue) -> Parsed<String, ParseIssue> { .invalid([]) }
}

struct JSONAdditionalPropertiesParsingTests {
  @Test func metadataNamedKeysAreAdditionalButDeclaredPropertiesAreNot() throws {
    let schema = JSONObject {
      JSONProperty(key: "known") { JSONInteger() }.required()
    }
    .additionalProperties { JSONString() }
    let input: JSONValue = [
      "known": 3, "type": "one", "properties": "two", "required": "three",
      "additionalProperties": "four",
    ]
    let result = try schema.parseAndValidate(input)
    #expect(result.0 == 3)
    #expect(
      result.1.matches == [
        "type": "one", "properties": "two", "required": "three", "additionalProperties": "four",
      ]
    )
  }

  @Test func matchingPatternsAreExcludedInEitherModifierOrder() throws {
    let input: JSONValue = ["x-value": 4, "type": "extra"]
    let first = JSONObject()
      .patternProperties { JSONProperty(key: "^x-") { JSONInteger() }.required() }
      .additionalProperties { JSONString() }
    let second = JSONObject()
      .additionalProperties { JSONString() }
      .patternProperties { JSONProperty(key: "^x-") { JSONInteger() }.required() }
    #expect(try first.parseAndValidate(input).1.matches == ["type": "extra"])
    #expect(try second.parseAndValidate(input).0.1.matches == ["type": "extra"])
    #expect(first.parse(input).value?.1.matches == ["type": "extra"])
    #expect(second.parse(input).value?.0.1.matches == ["type": "extra"])
  }

  @Test func additionalFailuresAreNotDroppedAndCombineWithBaseFailures() throws {
    let schema = JSONObject {
      JSONProperty(key: "known") { JSONInteger() }.required()
    }
    .additionalProperties { JSONString() }
    let issues = try #require(schema.parse(["known": "not-an-integer", "extra": false]).errors)
    #expect(issues.count == 2)
    #expect(issues.contains(.typeMismatch(expected: .integer, actual: "not-an-integer")))
    #expect(issues.contains(.typeMismatch(expected: .string, actual: false)))
    #expect(throws: ParseAndValidateIssue.self) {
      try schema.parseAndValidate(["known": 3, "extra": false])
    }
  }

  @Test func emptyCustomFailuresStillRejectTheObject() {
    let schema = JSONObject().additionalProperties { EmptyAdditionalFailure() }
    #expect(schema.parse(["extra": "hello"]).errors != nil)
    #expect(throws: ParseAndValidateIssue.self) { try schema.parseAndValidate(["extra": "hello"]) }
  }

  @Test func invalidPatternsAreReportedInsteadOfGuessingAdditionalKeys() throws {
    var object = JSONObject()
    object.schemaValue["patternProperties"] = ["[": true]
    let issues = try #require(
      object.additionalProperties { JSONString() }.parse(["extra": "hello"]).errors
    )
    guard case .invalidRegularExpression(let pattern, let reason) = issues.first else {
      Issue.record("Expected the invalid pattern to be reported")
      return
    }
    #expect(pattern == "[")
    #expect(!reason.isEmpty)
  }
}
