import JSONSchema
import JSONSchemaBuilder
import Testing

private struct HexColor: Equatable, Sendable {
  let canonicalValue: String

  init?(hexString: String) {
    let normalized = hexString.uppercased()
    guard normalized.count == 7,
      normalized.first == "#",
      normalized.dropFirst().allSatisfy(\.isHexDigit)
    else {
      return nil
    }
    canonicalValue = normalized
  }
}

private struct CanonicalHexColorComponent: JSONSchemaComponent {
  var schemaValue = JSONString().schemaValue
  let color: HexColor

  func parse(_ value: JSONValue) -> Parsed<HexColor, ParseIssue> {
    guard case .string(let string) = value else {
      return .invalid([.typeMismatch(expected: .string, actual: value)])
    }
    guard string == color.canonicalValue else {
      return .invalid([
        .compositionFailure(
          type: .allOf,
          reason: "Hex color must be uppercase",
          nestedErrors: []
        )
      ])
    }
    return .valid(color)
  }
}

private struct PrefixStringComponent: JSONSchemaComponent {
  var schemaValue = JSONString().schemaValue
  let prefix: String

  func parse(_ value: JSONValue) -> Parsed<String, ParseIssue> {
    guard case .string(let string) = value else {
      return .invalid([.typeMismatch(expected: .string, actual: value)])
    }
    guard string.hasPrefix(prefix) else {
      return .invalid([
        .compositionFailure(
          type: .allOf,
          reason: "String must start with \(prefix)",
          nestedErrors: []
        )
      ])
    }
    return .valid(string)
  }
}

struct JSONEnumTests {
  @Test func singleValue() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .enumValues { "red" }
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "enum": ["red"],
    ]

    #expect(sample.schemaValue == .object(expected))
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

    let expected: [String: JSONValue] = [
      "type": "string",
      "enum": ["red", "amber", "green"],
    ]

    #expect(sample.schemaValue == .object(expected))
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

    let expected: [String: JSONValue] = [
      "enum": ["red", "amber", "green", nil, 42]
    ]

    #expect(sample.schemaValue == .object(expected))
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

    let expected: [String: JSONValue] = [
      "title": "Color",
      "type": "string",
      "enum": ["red", "amber", "green"],
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}

struct JSONConstantTests {
  @Test func constantOnly() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONAnyValue()
        .constant("red")
    }

    let expected: [String: JSONValue] = [
      "const": "red"
    ]

    #expect(sample.schemaValue == .object(expected))
  }

  @Test func string() {
    @JSONSchemaBuilder var sample: some JSONSchemaComponent {
      JSONString()
        .constant("red")
    }

    let expected: [String: JSONValue] = [
      "type": "string",
      "const": "red",
    ]

    #expect(sample.schemaValue == .object(expected))
  }
}

struct JSONMapModifierTests {
  @Test func compactMapTransformsHexColor() throws {
    let schema = JSONString()
      .compactMap { HexColor(hexString: $0) }

    let expectedColor = try #require(HexColor(hexString: "#FFAACC"))

    let valid: Parsed<HexColor, ParseIssue> = schema.parse(.string("#FFAACC"))
    #expect(valid.value == expectedColor)

    let invalid: Parsed<HexColor, ParseIssue> = schema.parse(.string("blue"))
    #expect(
      invalid.errors == [
        .compactMapValueNil(value: .string("blue"))
      ]
    )
  }

  @Test func flatMapAppliesCanonicalValidation() throws {
    let schema = JSONString()
      .compactMap { HexColor(hexString: $0) }
      .flatMap { CanonicalHexColorComponent(color: $0) }

    let uppercaseColor = try #require(HexColor(hexString: "#ABCDEF"))

    let uppercaseResult: Parsed<HexColor, ParseIssue> = schema.parse(.string("#ABCDEF"))
    #expect(uppercaseResult.value == uppercaseColor)

    let lowercaseResult: Parsed<HexColor, ParseIssue> = schema.parse(.string("#abcdef"))
    #expect(
      lowercaseResult.errors == [
        .compositionFailure(
          type: .allOf,
          reason: "Hex color must be uppercase",
          nestedErrors: []
        )
      ]
    )
  }
}

struct JSONConditionalModifierTests {
  @Test func firstBranchIsUsed() {
    let conditional = JSONComponents.Conditional<
      PrefixStringComponent,
      PrefixStringComponent
    >
    .first(PrefixStringComponent(prefix: "a"))

    #expect(conditional.parse(.string("abc")) == .valid("abc"))
    #expect(
      conditional.parse(.string("zzz"))
        == .invalid([
          .compositionFailure(
            type: .allOf,
            reason: "String must start with a",
            nestedErrors: []
          )
        ])
    )
    #expect(conditional.schemaValue == PrefixStringComponent(prefix: "a").schemaValue)
  }

  @Test func secondBranchIsUsed() {
    let conditional = JSONComponents.Conditional<
      PrefixStringComponent,
      PrefixStringComponent
    >
    .second(PrefixStringComponent(prefix: "b"))

    #expect(conditional.parse(.string("bbb")) == .valid("bbb"))
    #expect(
      conditional.parse(.string("ccc"))
        == .invalid([
          .compositionFailure(
            type: .allOf,
            reason: "String must start with b",
            nestedErrors: []
          )
        ])
    )
  }
}

struct JSONOptionalComponentTests {
  @Test func optionalComponentWrapsValue() {
    let optionalComponent = JSONComponents.OptionalComponent(wrapped: JSONInteger())
    #expect(optionalComponent.parse(.integer(5)) == .valid(5))
  }

  @Test func nilWrappedOptionalAcceptsAnyValue() {
    let optionalComponent = JSONComponents.OptionalComponent<JSONInteger>(wrapped: nil)
    #expect(optionalComponent.parse(.string("ignored")) == .valid(nil))
    #expect(optionalComponent.schemaValue == .object([:]))
  }
}

struct JSONMergedComponentTests {
  @Test func mergedComponentCombinesSchemasAndErrors() throws {
    let patternComponent = JSONComponents.PassthroughComponent(
      wrapped: JSONString().pattern("^a+$")
    )
    let minLengthComponent = JSONComponents.PassthroughComponent(
      wrapped: JSONString().minLength(2)
    )

    let merged = patternComponent.merging(with: minLengthComponent)
    let object = try #require(merged.schemaValue.object)

    #expect(object[Keywords.Pattern.name] == .string("^a+$"))
    #expect(object[Keywords.MinLength.name] == .integer(2))

    #expect(merged.parse(.string("aa")) == .valid(.string("aa")))
    #expect(
      merged.parse(.boolean(true))
        == .invalid([
          .typeMismatch(expected: .string, actual: .boolean(true)),
          .typeMismatch(expected: .string, actual: .boolean(true)),
        ])
    )
  }
}

struct JSONOrNullModifierTests {
  @Test func typeStyleIncludesNullAndAcceptsNil() throws {
    let schema = JSONString().orNull(style: .type)
    let object = try #require(schema.schemaValue.object)
    #expect(
      object[Keywords.TypeKeyword.name]
        == .array([
          .string(JSONType.string.rawValue),
          .string(JSONType.null.rawValue),
        ])
    )

    #expect(schema.parse(.string("value")) == .valid("value"))
    #expect(schema.parse(.null) == .valid(nil))
  }

  @Test func unionStyleBuildsOneOfSchema() throws {
    let schema = JSONString().orNull(style: .union)

    let object = try #require(schema.schemaValue.object)
    let oneOf = try #require(object[Keywords.OneOf.name])
    #expect(oneOf.array?.count == 2)

    #expect(schema.parse(.null) == .valid(nil))
    #expect(schema.parse(.string("Blob")) == .valid("Blob"))
  }
}

struct JSONMapModifierBehaviorTests {
  @Test func mapTransformsOutput() {
    let schema = JSONInteger().map { $0 * 2 }

    #expect(schema.parse(.integer(3)) == .valid(6))
    #expect(
      schema.parse(.string("nope"))
        == .invalid([
          .typeMismatch(expected: .integer, actual: .string("nope"))
        ])
    )
  }
}
