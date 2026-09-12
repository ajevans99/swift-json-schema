import JSONSchemaBuilder
import Testing

@testable import JSONSchema

private struct ProjectionName: Schemable, Equatable {
  let value: String

  static var schema: some JSONSchemaComponent<ProjectionName> {
    JSONString().map { ProjectionName(value: $0) }
  }
}

private enum ProjectionValue: Equatable {
  case name(ProjectionName)
  case flag(Bool)
}

private struct ProjectionFormat: FormatValidator {
  let formatName = "projection-prefix"
  let prefix: String
  func validate(_ value: String) -> Bool { value.hasPrefix(prefix) }
}

private indirect enum ProjectionNode: Schemable, Equatable {
  case name(ProjectionName)
  case list([ProjectionNode])

  static var definition: SchemaValue {
    [
      "allOf": [
        [
          "anyOf": [
            ["$ref": "#/$defs/name"],
            ["type": "array", "items": ["$ref": "#/$defs/node"]],
          ]
        ]
      ]
    ]
  }

  static var schema: some JSONSchemaComponent<ProjectionNode> {
    JSONComposition.AnyOf(into: ProjectionNode.self) {
      JSONReference<ProjectionName>.definition(named: "name").map { ProjectionNode.name($0) }
      JSONArray {
        JSONReference<ProjectionNode>.definition(named: "node")
      }
      .map { ProjectionNode.list($0) }
    }
    .projection(schemaValue: definition)
  }
}

private struct ProjectionRoot: Schemable, Equatable {
  let node: ProjectionNode

  static var schema: some JSONSchemaComponent<ProjectionRoot> {
    let object = JSONObject {
      JSONProperty(key: "node") {
        JSONComposition.AllOf(into: ProjectionNode.self) {
          ProjectionNode.schema
        }
      }
      .required()
    }
    var complete = SchemaValue.object(["allOf": [object.schemaValue.value]])
    complete["$defs"] = [
      "name": JSONString().minLength(2).schemaValue.value,
      "node": ProjectionNode.definition.value,
    ]
    return object.map { ProjectionRoot(node: $0) }.projection(schemaValue: complete)
  }
}

struct JSONProjectionTests {
  private static var complete: SchemaValue {
    [
      "$defs": ["name": ["type": "string"]],
      "allOf": [
        ["anyOf": [["$ref": "#/$defs/name"], ["type": "boolean"]]]
      ],
    ]
  }

  private static var union: some JSONSchemaComponent<ProjectionValue> {
    JSONComposition.AnyOf(into: ProjectionValue.self) {
      JSONReference<ProjectionName>.definition(named: "name").map { ProjectionValue.name($0) }
      JSONBoolean().map { ProjectionValue.flag($0) }
    }
  }

  @Test func referenceCompositionCanUseADifferentValidationShape() throws {
    let projection = JSONComponents.Projection(upstream: Self.union, schemaValue: Self.complete)
    #expect(projection.schemaValue == Self.complete)
    #expect(projection.definition().validate("hello").isValid)
    #expect(projection.parse("hello") == .valid(.name(ProjectionName(value: "hello"))))
    #expect(try projection.parseAndValidate("hello") == .name(ProjectionName(value: "hello")))
    #expect(try projection.parseAndValidate(false) == .flag(false))
    #expect(throws: ParseAndValidateIssue.self) { try projection.parseAndValidate(42) }
  }

  @Test func completeSchemaRemainsAuthoritativeAndMutable() throws {
    var complete = Self.complete
    complete["not"] = ["const": "forbidden"]
    var projection = Self.union.projection(schemaValue: complete)
    #expect(projection.schemaValue == complete)
    #expect(projection.parse("forbidden").value == .name(ProjectionName(value: "forbidden")))
    do {
      _ = try projection.parseAndValidate("forbidden")
      Issue.record("The complete schema must reject a value the projection can parse")
    } catch {
      guard case .validationFailed = error else {
        Issue.record("Expected complete-schema validation failure, received \(error)")
        return
      }
    }
    projection.schemaValue = Self.complete
    #expect(
      try projection.parseAndValidate("forbidden") == .name(ProjectionName(value: "forbidden"))
    )
    #expect(Self.union.schemaValue["$defs"] == nil)
  }

  @Test func nestedRecursiveProjectionsInheritDefinitionsThroughObjectsArraysAndAllOf() throws {
    let value: JSONValue = ["node": ["hello", ["world"]]]
    let expected = ProjectionRoot(
      node: .list([
        .name(ProjectionName(value: "hello")), .list([.name(ProjectionName(value: "world"))]),
      ])
    )
    #expect(ProjectionRoot.schema.parse(value) == .valid(expected))
    #expect(try ProjectionRoot.schema.parseAndValidate(value) == expected)
    #expect(ProjectionRoot.schema.parse(["node": ["x"]]).errors != nil)
    #expect(throws: ParseAndValidateIssue.self) {
      try ProjectionRoot.schema.parseAndValidate(["node": ["x"]])
    }
  }

  @Test func directTypedReferenceCanEnterAProjectionWithoutAnExistingParsingContext() {
    let reference = JSONReference<ProjectionRoot>.definition(named: "root")
    #expect(
      reference.parse(["node": "hello"])
        == .valid(ProjectionRoot(node: .name(ProjectionName(value: "hello"))))
    )
  }

  @Test func aProjectedReferenceRootKeepsItsRecordedTarget() throws {
    var complete = ProjectionNode.definition
    complete["$defs"] = [
      "node": ProjectionNode.definition.value,
      "name": JSONString().schemaValue.value,
    ]
    let projection = JSONReference<ProjectionNode>.definition(named: "node")
      .projection(schemaValue: complete)
    #expect(
      try projection.parseAndValidate(["hello"]) == .list([.name(ProjectionName(value: "hello"))])
    )
  }

  @Test func nestedReferenceBranchesUseCallerFormatsWithoutLeakingBetweenCalls() throws {
    let union = JSONComposition.AnyOf(into: String.self) {
      JSONReference<ProjectionName>.definition(named: "formatted").map { "formatted:\($0.value)" }
      JSONString().map { "fallback:\($0)" }
    }
    let nested = union.projection(schemaValue: ["allOf": [union.schemaValue.value]])
    let object = JSONObject { JSONProperty(key: "value", value: nested).required() }
    var complete = SchemaValue.object(["allOf": [object.schemaValue.value]])
    complete["$defs"] = ["formatted": ["type": "string", "format": "projection-prefix"]]
    let projection = object.projection(schemaValue: complete)
    let context = Context(
      dialect: .draft2020_12,
      formatValidators: [ProjectionFormat(prefix: "A")]
    )
    #expect(
      try projection.parseAndValidate(["value": "Bob"], validationContext: context)
        == "fallback:Bob"
    )
    #expect(
      try projection.parseAndValidate(["value": "Alice"], validationContext: context)
        == "formatted:Alice"
    )
    #expect(projection.parse(["value": "Bob"]).value == "formatted:Bob")
    #expect(try projection.parseAndValidate(["value": "Bob"]) == "formatted:Bob")
    #expect(
      try projection.parseAndValidate(
        ["value": "Bob"],
        validationContext: Context(
          dialect: .draft2020_12,
          formatValidators: [ProjectionFormat(prefix: "B")]
        )
      ) == "formatted:Bob"
    )
    #expect(context.rootRawSchema == nil)
    #expect(context.schemaCache.isEmpty)
    #expect(context.documentCache.isEmpty)
    #expect(context.dynamicScopes.isEmpty)
  }

  @Test func reusedCallerContextIsNotMutatedOrUsedAsADefinitionCache() throws {
    let context = Context(dialect: .draft2020_12)
    let original: JSONValue = ["$defs": ["name": ["const": "original"]]]
    let originalSchema = try Schema(rawSchema: original, context: context)
    #expect(originalSchema.validate("original").isValid)
    let documents = Set(context.documentCache.keys)
    let cache = Set(context.schemaCache.keys)
    let identifiers = Set(context.identifierRegistry.keys)

    for name in ["first", "second", "first"] {
      var complete = Self.complete
      complete["$defs"] = ["name": ["const": .string(name)]]
      let projection = Self.union.projection(schemaValue: complete)
      #expect(
        try projection.parseAndValidate(.string(name), validationContext: context)
          == .name(ProjectionName(value: name))
      )
      #expect(throws: ParseAndValidateIssue.self) {
        try projection.parseAndValidate("original", validationContext: context)
      }
    }
    #expect(context.rootRawSchema == original)
    #expect(Set(context.documentCache.keys) == documents)
    #expect(Set(context.schemaCache.keys) == cache)
    #expect(Set(context.identifierRegistry.keys) == identifiers)
    #expect(context.dynamicScopes.isEmpty)
    #expect(context.activeVocabularies == nil)
  }

  @Test func completeStandardVocabularyIsSupported() throws {
    var complete = Self.complete
    complete["$schema"] = .string(Dialect.draft2020_12.rawValue)
    complete["$vocabulary"] = [
      "https://json-schema.org/draft/2020-12/vocab/core": true,
      "https://json-schema.org/draft/2020-12/vocab/applicator": true,
      "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
      "https://json-schema.org/draft/2020-12/vocab/validation": true,
      "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
      "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
      "https://json-schema.org/draft/2020-12/vocab/content": true,
    ]
    let projection = Self.union.projection(schemaValue: complete)
    #expect(try projection.parseAndValidate("hello") == .name(ProjectionName(value: "hello")))
    #expect(projection.schemaValue == complete)
  }

  @Test func identifiersAreHarmlessInReferenceFreeProjections() throws {
    var string = JSONString().minLength(2)
    string.schemaValue["$id"] = "child"
    let union = JSONComposition.AnyOf(into: String.self) {
      string
    }
    let complete: SchemaValue = [
      "$id": "https://example.com/root",
      "allOf": [union.schemaValue.value],
    ]
    #expect(try union.projection(schemaValue: complete).parseAndValidate("hello") == "hello")
  }

  @Test func keywordLikeInstanceDataDoesNotChangeTheProjectionPolicy() throws {
    let data: JSONValue = ["$id": "data", "$ref": "remote", "$vocabulary": ["custom": true]]
    let object = JSONObject {
      JSONProperty(key: "$schema") { JSONString() }.required()
      JSONProperty(key: "$vocabulary") { JSONAnyValue() }.required()
    }
    var complete = SchemaValue.object(["allOf": [object.schemaValue.value]])
    complete["examples"] = [data]
    complete["default"] = data
    let input: JSONValue = ["$schema": "data", "$vocabulary": data]
    let output = try object.projection(schemaValue: complete).parseAndValidate(input)
    #expect(output.0 == "data")
    #expect(output.1 == data)
  }

  @Test(arguments: [
    SchemaValue.object(["$vocabulary": ["https://json-schema.org/draft/2020-12/vocab/core": true]]),
    SchemaValue.object(["$vocabulary": ["https://example.com/custom": true]]),
    SchemaValue.object(["$schema": "https://example.com/custom"]),
    SchemaValue.object(["$dynamicRef": "#/$defs/name"]),
    SchemaValue.object(["$ref": "https://example.com/remote"]),
    SchemaValue.object(["$ref": "#/$defs/missing"]),
    SchemaValue.object(["$ref": "#/$defs/name", "$id": "child", "$defs": ["name": true]]),
    SchemaValue.object(["allOf": [42]]),
  ])
  func unsupportedOrMalformedBundlesFailExplicitly(complete: SchemaValue) throws {
    let projection = JSONString().projection(schemaValue: complete)
    let issues = try #require(projection.parse("hello").errors)
    guard case .projectionFailure(let reason) = issues.first else {
      Issue.record("Expected an explicit projection scope or construction failure")
      return
    }
    #expect(!reason.isEmpty)
    #expect(throws: ParseAndValidateIssue.self) { try projection.parseAndValidate("hello") }
  }

  @Test func conflictsDoNotSilentlyReplaceRootDefinitions() throws {
    var upstream = Self.union
    upstream.schemaValue["$defs"] = ["name": ["type": "boolean"]]
    let projection = upstream.projection(schemaValue: Self.complete)
    #expect(
      projection.parse("hello").errors
        == [.projectionFailure(reason: "conflicting root definition 'name'")]
    )
  }

  @Test func customVocabularyInEnclosingSchemaCannotBeDiscarded() throws {
    let projection = Self.union.projection(schemaValue: Self.complete)
    var object = JSONObject { JSONProperty(key: "value", value: projection).required() }
    object.schemaValue["$vocabulary"] = [
      "https://json-schema.org/draft/2020-12/vocab/core": true,
      "https://json-schema.org/draft/2020-12/vocab/applicator": true,
    ]
    #expect(object.parse(["value": "hello"]).errors != nil)
    #expect(throws: ParseAndValidateIssue.self) { try object.parseAndValidate(["value": "hello"]) }
  }

  @Test func anErasedMismatchedReferenceStillCannotBorrowADifferentTarget() throws {
    var erased = Self.union.eraseToAnySchemaComponent()
    erased.schemaValue = .boolean(true)
    let projection = erased.projection(schemaValue: Self.complete)
    let issues = try #require(projection.parse("hello").errors)
    guard case .compositionFailure(.anyOf, let reason, _) = issues.first else {
      Issue.record("Expected the original branch-safety refusal")
      return
    }
    #expect(reason.contains("branch validation is unavailable"))
  }

  @Test func referencedAnnotationDataMustAlsoBeASupportedSchema() throws {
    let reference = JSONReference<ProjectionName>(uri: "#/$defs/holder/default")
    let complete: SchemaValue = [
      "$defs": [
        "holder": [
          "default": ["$ref": "#/$defs/holder/examples/0"],
          "examples": [["$vocabulary": ["https://example.com/custom": true]]],
        ]
      ]
    ]
    let issues = try #require(
      reference.projection(schemaValue: complete).parse("hi").errors
    )
    guard case .projectionFailure(let reason) = issues.first else {
      Issue.record("Referenced annotation data must not bypass the projection scope policy")
      return
    }
    #expect(reason.contains("vocabularies"))
  }

  @Test func callerCannotRedefineTheStandardVocabularyForProjections() throws {
    let context = Context(
      dialect: .draft2020_12,
      remoteSchema: [
        Dialect.draft2020_12.rawValue: [
          "$vocabulary": ["https://json-schema.org/draft/2020-12/vocab/core": true]
        ]
      ]
    )
    var complete = Self.complete
    complete["$schema"] = .string(Dialect.draft2020_12.rawValue)
    do {
      _ = try Self.union.projection(schemaValue: complete)
        .parseAndValidate(
          "hello",
          validationContext: context
        )
      Issue.record("A caller's custom vocabulary must not be silently replaced")
    } catch {
      guard case .parsingFailed(let issues) = error,
        case .projectionFailure(let reason) = issues.first
      else {
        Issue.record("Expected a projection vocabulary error, received \(error)")
        return
      }
      #expect(reason.contains("caller overrides"))
    }
  }

  @Test func escapedDefinitionNamesAndBooleanTargetsResolve() throws {
    let union = JSONComposition.AnyOf(into: String.self) {
      JSONReference<ProjectionName>(uri: "#/$defs/a~1b~0c").map { $0.value }
      JSONString()
    }
    let complete: SchemaValue = [
      "$defs": ["a/b~c": true],
      "allOf": [union.schemaValue.value],
    ]
    #expect(try union.projection(schemaValue: complete).parseAndValidate("hello") == "hello")
  }

  @Test func concurrentCallsCanShareConfigurationWithoutSharingRoots() async throws {
    let context = Context(dialect: .draft2020_12)
    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0 ..< 20 {
        group.addTask {
          let value = "name-\(index)"
          var complete = Self.complete
          complete["$defs"] = ["name": ["const": .string(value)]]
          let output = try Self.union.projection(schemaValue: complete)
            .parseAndValidate(
              .string(value),
              validationContext: context
            )
          #expect(output == .name(ProjectionName(value: value)))
        }
      }
      try await group.waitForAll()
    }
    #expect(context.rootRawSchema == nil)
    #expect(context.documentCache.isEmpty)
    #expect(context.schemaCache.isEmpty)
  }

  @Test(arguments: [
    Dialect.draft2020_12.supportedVocabularies,
    Set(
      ["core", "applicator", "validation"]
        .map { "https://json-schema.org/draft/2020-12/vocab/" + $0 }
    ),
  ])
  func typeArrayWithStandardVocabularyAndUnknownExtensionDataUsesItsOwnUnion(
    vocabularies: Set<String>
  ) throws {
    let union = JSONComposition.AnyOf(into: ProjectionValue.self) {
      JSONString().map { ProjectionValue.name(ProjectionName(value: $0)) }
      JSONBoolean().map { ProjectionValue.flag($0) }
    }
    var complete: SchemaValue = [
      "type": ["string", "boolean"],
      "x-extension": ["$ref": "remote", "$vocabulary": ["custom": true], "$schema": "custom"],
    ]
    complete["$vocabulary"] = .object(
      .init(
        uniqueKeysWithValues: vocabularies.map {
          ($0, .boolean(true))
        }
      )
    )
    let projection = union.projection(schemaValue: complete)
    #expect(try projection.parseAndValidate("hello") == .name(ProjectionName(value: "hello")))
    #expect(try projection.parseAndValidate(true) == .flag(true))
    #expect(projection.schemaValue == complete)
  }

  @Test(arguments: ["format", "unevaluatedProperties", "contentEncoding"])
  func omittedVocabulariesCannotSilentlyBecomeEnabled(keyword: String) throws {
    let complete: SchemaValue = [
      "$vocabulary": [
        "https://json-schema.org/draft/2020-12/vocab/core": true,
        "https://json-schema.org/draft/2020-12/vocab/applicator": true,
        "https://json-schema.org/draft/2020-12/vocab/validation": true,
      ]
    ]
    var parser = JSONString()
    parser.schemaValue[keyword] = keyword == "unevaluatedProperties" ? false : "example"
    let issues = try #require(parser.projection(schemaValue: complete).parse("hello").errors)
    guard case .projectionFailure(let reason) = issues.first else {
      Issue.record("Omitted evaluation vocabularies must not be silently enabled")
      return
    }
    #expect(reason.contains("omitted vocabularies"))
  }

  @Test func projectedAdditionalPropertiesRetainReferenceBranchScope() throws {
    let object = JSONObject {
      JSONProperty(key: "known") { JSONInteger() }.required()
    }
    .additionalProperties { Self.union }
    let complete: SchemaValue = [
      "allOf": [object.schemaValue.value],
      "$defs": ["name": ["type": "string"]],
    ]
    let result = try object.projection(schemaValue: complete)
      .parseAndValidate(["known": 3, "type": "hello", "flag": false])
    #expect(result.0 == 3)
    #expect(
      result.1.matches == ["type": .name(ProjectionName(value: "hello")), "flag": .flag(false)]
    )
  }
}
