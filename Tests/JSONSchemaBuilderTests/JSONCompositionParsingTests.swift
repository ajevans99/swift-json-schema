import JSONSchema
import JSONSchemaBuilder
import Testing

private enum UnionValue: Equatable {
  case long(String)
  case short(String)
  case integer(Int)
  case boolean(Bool)
  case null
}

private struct RawStringComponent: JSONSchemaComponent {
  var schemaValue: SchemaValue

  func parse(_ value: JSONValue) -> Parsed<String, ParseIssue> {
    JSONString().parse(value)
  }
}

private struct EmptyFailureComponent: JSONSchemaComponent {
  var schemaValue = JSONString().schemaValue

  func parse(_ value: JSONValue) -> Parsed<String, ParseIssue> { .invalid([]) }
}

private struct PrefixFormat: FormatValidator {
  let formatName = "starts-with-A"
  func validate(_ value: String) -> Bool { value.hasPrefix("A") }
}

private struct ReferencedUnion: Schemable, Equatable {
  let value: UnionValue

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  static var schema: some JSONSchemaComponent<ReferencedUnion> {
    JSONComposition.OneOf(into: UnionValue.self) {
      JSONString().minLength(5).map { UnionValue.long($0) }
      JSONString().maxLength(3).map { UnionValue.short($0) }
    }
    .map { ReferencedUnion(value: $0) }
  }
}

struct JSONCompositionParsingTests {
  @Test(arguments: ["hi", "hello"])
  func sameOutputOneOfUsesLengthConstraints(value: String) throws {
    let schema = JSONComposition.OneOf(into: String.self) {
      JSONString().minLength(5)
      JSONString().maxLength(3)
    }

    #expect(schema.definition().validate(.string(value)).isValid)
    #expect(schema.parse(.string(value)) == .valid(value))
    #expect(try schema.parseAndValidate(.string(value)) == value)
  }

  @Test func anyOfPreservesFirstSchemaValidMapping() throws {
    let schema = JSONComposition.AnyOf(into: UnionValue.self) {
      JSONString().minLength(5).map { UnionValue.long($0.uppercased()) }
      JSONString().maxLength(5).map { UnionValue.short($0) }
    }

    #expect(schema.parse("hi") == .valid(.short("hi")))
    #expect(try schema.parseAndValidate("hi") == .short("hi"))
    #expect(try schema.parseAndValidate("hello") == .long("HELLO"))
    #expect(try schema.parseAndValidate(instance: #""hi""#) == .short("hi"))
  }

  @Test func anyOfSkipsSchemaInvalidTransforms() {
    let schema = JSONComposition.AnyOf(into: String.self) {
      JSONString().minLength(5)
        .map {
          Issue.record("A schema-invalid branch must not run its transform")
          return $0
        }
      JSONString().maxLength(3)
    }

    #expect(schema.parse("hi") == .valid("hi"))
  }

  @Test func sameTypeEnumBranchesUsePatternAndConstant() throws {
    let schema = JSONComposition.OneOf(into: UnionValue.self) {
      JSONString().pattern("^long-").map { UnionValue.long($0) }
      JSONString().constant("short").map { UnionValue.short($0) }
    }

    #expect(try schema.parseAndValidate("short") == .short("short"))
    #expect(try schema.parseAndValidate("long-value") == .long("long-value"))
    #expect(schema.parse("unmatched").errors != nil)
  }

  @Test func mixedPayloadUnionIncludesNull() throws {
    let schema = JSONComposition.OneOf(into: UnionValue.self) {
      JSONString().minLength(5).map { UnionValue.long($0) }
      JSONString().maxLength(3).map { UnionValue.short($0) }
      JSONInteger().minimum(0).map { UnionValue.integer($0) }
      JSONBoolean().map { UnionValue.boolean($0) }
      JSONNull().map { UnionValue.null }
    }

    #expect(try schema.parseAndValidate("hi") == .short("hi"))
    #expect(try schema.parseAndValidate(7) == .integer(7))
    #expect(try schema.parseAndValidate(true) == .boolean(true))
    #expect(try schema.parseAndValidate(.null) == .null)
    #expect(schema.parse(-1).errors != nil)
  }

  @Test func oneOfReportsAmbiguityAndNoMatch() throws {
    let overlapping = JSONComposition.OneOf(into: String.self) {
      JSONString().minLength(2)
      JSONString().maxLength(5)
    }
    #expect(
      overlapping.parse("hello").errors == [
        .compositionFailure(type: .oneOf, reason: "multiple matches found", nestedErrors: [])
      ]
    )
    #expect(throws: ParseAndValidateIssue.self) {
      try overlapping.parseAndValidate("hello")
    }

    let disjoint = JSONComposition.OneOf(into: String.self) {
      JSONString().minLength(5)
      JSONString().maxLength(3)
    }
    let errors = try #require(disjoint.parse("four").errors)
    guard case .compositionFailure(.oneOf, "no match found", let nested) = errors.first else {
      Issue.record("Expected a oneOf no-match error")
      return
    }
    #expect(nested.count == 2)
    guard case .runtimeValidationIssue(let result) = nested[0] else {
      Issue.record("Expected the branch's schema validation error")
      return
    }
    #expect(result.errors?.first?.keyword == "minLength")
    #expect(result.keywordLocation == JSONPointer(tokens: ["oneOf", "0"]))
    #expect(throws: ParseAndValidateIssue.self) { try disjoint.parseAndValidate("four") }
  }

  @Test func customParseFailuresStillParticipateInSelection() throws {
    let any = JSONComposition.AnyOf(into: UnionValue.self) {
      JSONString().compactMap { _ -> UnionValue? in nil }
      JSONString().map { UnionValue.short($0) }
    }
    #expect(try any.parseAndValidate("hi") == .short("hi"))

    let one = JSONComposition.OneOf(into: UnionValue.self) {
      JSONString().compactMap { _ -> UnionValue? in nil }
      JSONString().map { UnionValue.short($0) }
    }
    #expect(one.parse("hi") == .valid(.short("hi")))
    #expect(throws: ParseAndValidateIssue.self) { try one.parseAndValidate("hi") }

    let rejected = JSONComposition.AnyOf(into: String.self) {
      JSONString().compactMap { _ -> String? in nil }
    }
    do {
      _ = try rejected.parseAndValidate("hi")
      Issue.record("Expected custom parsing failure")
    } catch {
      guard case .parsingFailed(let errors) = error else {
        Issue.record("Expected custom parsing failure, received \(error)")
        return
      }
      #expect(
        errors == [
          .compositionFailure(
            type: .anyOf,
            reason: "did not match any",
            nestedErrors: [.compactMapValueNil(value: "hi")]
          )
        ]
      )
    }
  }

  @Test func allOfChecksEverySchemaAndKeepsFirstOutput() throws {
    let schema = JSONComposition.AllOf(into: String.self) {
      JSONString().minLength(3).map { $0.uppercased() }
      JSONString().pattern("^a").map { "second: \($0)" }
    }

    #expect(try schema.parseAndValidate("abc") == "ABC")
    #expect(schema.parse("ab").errors != nil)
    #expect(schema.parse("xyz").errors != nil)

    let emptyFailure = JSONComposition.AllOf(into: String.self) {
      JSONString()
      EmptyFailureComponent()
    }
    #expect(
      emptyFailure.parse("abc").errors == [
        .compositionFailure(type: .allOf, reason: "did not match all", nestedErrors: [])
      ]
    )
  }

  @Test func allOfPreservesAnOptionalFirstOutput() throws {
    let schema = JSONComposition.AllOf(into: String?.self) {
      JSONString().map { _ -> String? in nil }
      JSONString().map { Optional($0) }
    }
    #expect(schema.parse("abc") == .valid(nil))
    #expect(try schema.parseAndValidate("abc") == nil)
  }

  @Test func notUsesSchemaConstraintsAndCustomParsing() throws {
    let schema = JSONComposition.Not { JSONString().minLength(5) }
    #expect(schema.parse("hi") == .valid("hi"))
    #expect(try schema.parseAndValidate("hi") == "hi")
    #expect(schema.parse("hello").errors != nil)

    let custom = JSONComposition.Not {
      JSONString().compactMap { _ -> String? in nil }
    }
    #expect(custom.parse("hi") == .valid("hi"))
    #expect(throws: ParseAndValidateIssue.self) { try custom.parseAndValidate("hi") }
  }

  @Test func booleanSchemasParticipateInCompositions() throws {
    let never: JSONBooleanSchema = false
    let always: JSONBooleanSchema = true
    let any = JSONComposition.AnyOf(into: String.self) {
      never.map { _ in "never" }
      always.map { _ in "always" }
    }
    #expect(try any.parseAndValidate(.null) == "always")
    let one = JSONComposition.OneOf(into: String.self) {
      never.map { _ in "never" }
      always.map { _ in "always" }
    }
    #expect(try one.parseAndValidate(.null) == "always")
    let all = JSONComposition.AllOf(into: String.self) {
      always.map { _ in "always" }
      never.map { _ in "never" }
    }
    #expect(all.parse(.null).errors != nil)
    #expect(try JSONComposition.Not { never }.parseAndValidate(.null) == .null)
    #expect(JSONComposition.Not { always }.parse(.null).errors != nil)
  }

  @Test func nestedObjectsUseConstantDiscriminators() throws {
    let schema = JSONComposition.OneOf(into: UnionValue.self) {
      JSONObject {
        JSONProperty(key: "tag") { JSONString().constant("long") }.required()
        JSONProperty(key: "payload") {
          JSONObject {
            JSONProperty(key: "value") { JSONString().minLength(5) }.required()
          }
        }
        .required()
      }
      .map { UnionValue.long($0.1) }
      JSONObject {
        JSONProperty(key: "tag") { JSONString().constant("short") }.required()
        JSONProperty(key: "payload") {
          JSONObject {
            JSONProperty(key: "value") { JSONString().maxLength(3) }.required()
          }
        }
        .required()
      }
      .map { UnionValue.short($0.1) }
    }

    let input: JSONValue = ["tag": "short", "payload": ["value": "hi"]]
    #expect(try schema.parseAndValidate(input) == .short("hi"))
    #expect(schema.parse(["tag": "long", "payload": ["value": "hi"]]).errors != nil)
  }

  @Test func nestedArraysAndNullableCompositionKeepTheirScope() throws {
    let schema = JSONObject {
      JSONProperty(key: "a/b~c") {
        JSONArray {
          JSONComposition.OneOf(into: UnionValue.self) {
            JSONString().minLength(5).map { UnionValue.long($0) }
            JSONString().maxLength(3).map { UnionValue.short($0) }
          }
          .orNull(style: .union)
        }
      }
      .required()
    }
    let input: JSONValue = ["a/b~c": ["hello", .null, "hi"]]
    #expect(schema.parse(input).value == [.long("hello"), nil, .short("hi")])
    #expect(try schema.parseAndValidate(input) == [.long("hello"), nil, .short("hi")])
  }

  @Test func callerFormatValidatorsControlBranchSelection() throws {
    let schema = JSONComposition.AnyOf(into: UnionValue.self) {
      JSONString().format("starts-with-A").map { UnionValue.long($0) }
      JSONString().map { UnionValue.short($0) }
    }
    #expect(try schema.parseAndValidate("Bob") == .long("Bob"))
    #expect(
      try schema.parseAndValidate(
        "Bob",
        validationContext: Context(dialect: .draft2020_12, formatValidators: [PrefixFormat()])
      ) == .short("Bob")
    )
    #expect(
      try schema.parseAndValidate(
        "Alice",
        validationContext: Context(dialect: .draft2020_12, formatValidators: [PrefixFormat()])
      ) == .long("Alice")
    )
  }

  @Test func localReferencesResolveAgainstEnclosingDefinitions() throws {
    var schema = JSONObject {
      JSONProperty(key: "value") {
        JSONComposition.AnyOf(into: UnionValue.self) {
          RawStringComponent(schemaValue: .object(["$ref": "#/$defs/long"]))
            .map { UnionValue.long($0) }
          RawStringComponent(schemaValue: .object(["$ref": "#/$defs/short"]))
            .map { UnionValue.short($0) }
        }
      }
      .required()
    }
    schema.schemaValue["$defs"] = [
      "long": JSONString().minLength(5).schemaValue.value,
      "short": JSONString().maxLength(3).schemaValue.value,
    ]
    #expect(schema.parse(["value": "hi"]).value == .short("hi"))
    #expect(try schema.parseAndValidate(["value": "hi"]) == .short("hi"))
  }

  @Test func inheritedIdentifiersAndRemoteReferencesKeepTheirContext() throws {
    let branch = JSONComposition.AnyOf(into: UnionValue.self) {
      RawStringComponent(schemaValue: .object(["$ref": "long.json"])).map { UnionValue.long($0) }
      JSONString().map { UnionValue.short($0) }
    }
    var first = JSONObject { JSONProperty(key: "value", value: branch).required() }
    first.schemaValue["$id"] = "https://example.com/first/"
    var second = JSONObject { JSONProperty(key: "value", value: branch).required() }
    second.schemaValue["$id"] = "https://example.com/second/"
    let schema = JSONObject {
      JSONProperty(key: "first", value: first).required()
      JSONProperty(key: "second", value: second).required()
    }
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        "https://example.com/first/long.json": JSONString().minLength(5).schemaValue.value,
        "https://example.com/second/long.json": JSONString().maxLength(3).schemaValue.value,
      ]
    )
    let output = try schema.parseAndValidate(
      ["first": ["value": "hi"], "second": ["value": "hi"]],
      validationContext: context
    )
    #expect(output.0 == .short("hi"))
    #expect(output.1 == .long("hi"))
  }

  @Test func dynamicReferencesUseTheEnclosingDynamicScope() throws {
    var schema = JSONComposition.AnyOf(into: UnionValue.self) {
      RawStringComponent(schemaValue: .object(["$dynamicRef": "inner#kind"]))
        .map {
          UnionValue.long($0)
        }
      JSONString().map { UnionValue.short($0) }
    }
    schema.schemaValue["$id"] = "https://example.com/root"
    schema.schemaValue["$defs"] = [
      "outer": ["$dynamicAnchor": "kind", "type": "string", "minLength": 5],
      "inner": ["$id": "inner", "$dynamicAnchor": "kind", "type": "string", "maxLength": 3],
    ]
    #expect(try schema.parseAndValidate("hi") == .short("hi"))
    #expect(try schema.parseAndValidate("hello") == .long("hello"))
  }

  @Test func typedReferencesDelegateInTheResolvedScope() throws {
    var schema = JSONObject {
      JSONProperty(key: "static") {
        JSONReference<ReferencedUnion>.definition(named: "Union")
      }
      .required()
      JSONProperty(key: "dynamic") {
        JSONDynamicReference<ReferencedUnion>(anchor: "union")
      }
      .required()
    }
    var definition = ReferencedUnion.schema.schemaValue
    definition["$dynamicAnchor"] = "union"
    schema.schemaValue["$defs"] = ["Union": definition.value]

    let result = try schema.parseAndValidate(["static": "hi", "dynamic": "hello"])
    #expect(result.0 == ReferencedUnion(value: .short("hi")))
    #expect(result.1 == ReferencedUnion(value: .long("hello")))
  }

  @Test func inheritedVocabularyControlsBranchValidity() throws {
    var schema = JSONComposition.AnyOf(into: UnionValue.self) {
      JSONString().minLength(5).map { UnionValue.long($0) }
      JSONString().maxLength(3).map { UnionValue.short($0) }
    }
    schema.schemaValue["$vocabulary"] = [
      "https://json-schema.org/draft/2020-12/vocab/core": true,
      "https://json-schema.org/draft/2020-12/vocab/applicator": true,
    ]
    #expect(try schema.parseAndValidate("hi") == .long("hi"))
  }

  @Test func allOfProjectionPreservesNestedUnionParsingAndOriginalValidation() throws {
    let union = JSONComposition.OneOf(into: UnionValue.self) {
      JSONString().minLength(5).map { UnionValue.long($0) }
      JSONString().maxLength(3).map { UnionValue.short($0) }
    }
    let first = JSONObject { JSONProperty(key: "name") { JSONString() }.required() }
    let second = JSONObject { JSONProperty(key: "value", value: union).required() }
    var projection = JSONObject {
      JSONProperty(key: "name") { JSONString() }.required()
      JSONProperty(key: "value", value: union).required()
    }
    .eraseToAnySchemaComponent()
    projection.schemaValue =
      JSONComposition.AllOf {
        first
        second
      }
      .schemaValue

    let output = try projection.parseAndValidate(["name": "sample", "value": "hi"])
    #expect(output.0 == "sample")
    #expect(output.1 == .short("hi"))
    #expect(throws: ParseAndValidateIssue.self) {
      try projection.parseAndValidate(["name": "sample", "value": "four"])
    }
  }

  @Test func projectedBranchesRetainCallerFormats() throws {
    let union = JSONComposition.AnyOf(into: UnionValue.self) {
      JSONString().format("starts-with-A").map { UnionValue.long($0) }
      JSONString().map { UnionValue.short($0) }
    }
    var projection = JSONObject {
      JSONProperty(key: "value", value: union).required()
    }
    .eraseToAnySchemaComponent()
    projection.schemaValue = .object(["allOf": [projection.schemaValue.value]])

    #expect(
      try projection.parseAndValidate(
        ["value": "Bob"],
        validationContext: Context(dialect: .draft2020_12, formatValidators: [PrefixFormat()])
      ) == .short("Bob")
    )
  }

  @Test func overriddenBranchOrderDoesNotReuseAnUnrelatedVerdict() throws {
    let long = JSONString().minLength(5).map { UnionValue.long($0) }
    let short = JSONString().maxLength(3).map { UnionValue.short($0) }
    var schema =
      JSONComposition.AnyOf(into: UnionValue.self) {
        long
        short
      }
      .eraseToAnySchemaComponent()
    schema.schemaValue = .object(["anyOf": [short.schemaValue.value, long.schemaValue.value]])

    #expect(try schema.parseAndValidate("hi") == .short("hi"))
  }

  @Test func unsupportedReferenceProjectionFailsExplicitly() throws {
    var projection = JSONObject {
      JSONProperty(key: "value") {
        JSONComposition.AnyOf(into: String.self) {
          RawStringComponent(schemaValue: .object(["$ref": "#/$defs/Text"]))
          JSONString()
        }
      }
      .required()
    }
    .eraseToAnySchemaComponent()
    projection.schemaValue = .object([
      "$defs": ["Text": JSONString().schemaValue.value],
      "allOf": [projection.schemaValue.value],
    ])

    do {
      _ = try projection.parseAndValidate(["value": "hi"])
      Issue.record("A referenced projection must not silently use a detached context")
    } catch {
      guard case .parsingFailed(let errors) = error else {
        Issue.record("Expected a parsing scope failure, received \(error)")
        return
      }
      guard case .compositionFailure(.anyOf, let reason, _) = errors.first else {
        Issue.record("Expected an explicit composition scope error")
        return
      }
      #expect(reason.contains("branch validation is unavailable"))
    }
  }

  @Test func objectModifiersPropagateCompositionScope() throws {
    let union = JSONComposition.OneOf(into: UnionValue.self) {
      RawStringComponent(schemaValue: .object(["$ref": "#/$defs/long"])).map { UnionValue.long($0) }
      JSONString().maxLength(3).map { UnionValue.short($0) }
    }
    var additional = JSONObject().additionalProperties { union }
    additional.schemaValue["$defs"] = ["long": JSONString().minLength(5).schemaValue.value]
    let additionalOutput = try additional.parseAndValidate(["extra": "hi"])
    #expect(additionalOutput.1.matches["extra"] == .short("hi"))

    var patterns = JSONObject()
      .patternProperties {
        JSONProperty(key: "^x-") { union }
      }
    patterns.schemaValue["$defs"] = ["long": JSONString().minLength(5).schemaValue.value]
    let patternOutput = try patterns.parseAndValidate(["x-value": "hi"])
    #expect(patternOutput.1.matches["x-value"]?.value == .short("hi"))

    var names = JSONObject()
      .propertyNames {
        JSONComposition.OneOf(into: String.self) {
          RawStringComponent(schemaValue: .object(["$ref": "#/$defs/long"]))
          JSONString().maxLength(3)
        }
      }
    names.schemaValue["$defs"] = ["long": JSONString().minLength(5).schemaValue.value]
    let namesOutput = try names.parseAndValidate(["hi": true])
    #expect(namesOutput.1.seen == ["hi"])
  }

  @Test func flatMapCanIntroduceASelfContainedComposition() throws {
    let schema = JSONString()
      .flatMap { _ in
        JSONComposition.OneOf(into: String.self) {
          JSONString().minLength(5)
          JSONString().maxLength(3)
        }
      }
    #expect(try schema.parseAndValidate("hi") == "hi")
  }

  @Test(arguments: [false, true], [false, true])
  func projectedTypedReferenceRequiresItsOwnRecordedTarget(
    dynamic: Bool,
    hasRecordedReference: Bool
  ) {
    var projection: JSONComponents.AnySchemaComponent<ReferencedUnion>
    if dynamic {
      projection = JSONDynamicReference<ReferencedUnion>(anchor: "Original")
        .eraseToAnySchemaComponent()
    } else {
      projection = JSONReference<ReferencedUnion>.definition(named: "Original")
        .eraseToAnySchemaComponent()
    }
    if hasRecordedReference {
      var replacement = ReferencedUnion.schema.schemaValue
      replacement["$dynamicAnchor"] = "Replacement"
      projection.schemaValue = .object([
        dynamic ? "$dynamicRef" : "$ref": dynamic ? "#Replacement" : "#/$defs/Replacement",
        "$defs": ["Replacement": replacement.value],
      ])
    } else {
      projection.schemaValue = .boolean(true)
    }

    do {
      _ = try projection.parseAndValidate("hi")
      Issue.record("Expected a scope failure instead of an unrelated or detached reference target")
    } catch {
      guard case .parsingFailed(let errors) = error,
        case .compositionFailure(.oneOf, let reason, _) = errors.first
      else {
        Issue.record("Expected an explicit composition scope error, received \(error)")
        return
      }
      #expect(reason.contains("branch validation is unavailable"))
    }
  }

  @Test func projectedBranchCannotHideItsCustomVocabulary() {
    var branch = JSONString().minLength(5)
    branch.schemaValue["$vocabulary"] = [
      "https://json-schema.org/draft/2020-12/vocab/core": true
    ]
    var projection =
      JSONComposition.AnyOf(into: String.self) {
        branch
        JSONString()
      }
      .eraseToAnySchemaComponent()
    projection.schemaValue = .boolean(true)

    do {
      _ = try projection.parseAndValidate("hi")
      Issue.record("Expected an explicit scope failure for the projected custom vocabulary")
    } catch {
      guard case .parsingFailed(let errors) = error,
        case .compositionFailure(.anyOf, let reason, _) = errors.first
      else {
        Issue.record("Expected an explicit composition scope error, received \(error)")
        return
      }
      #expect(reason.contains("branch validation is unavailable"))
    }
  }
}
