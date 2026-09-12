import Dispatch
import Foundation
import Testing

@testable import JSONSchema

struct EvaluationIsolationTests {
  @Test func nestedDynamicScopesShareTheirPrefix() {
    let context = Context(dialect: .draft2020_12)
    let depth = 128

    func descend(_ remaining: Int) {
      let parent = Context.evaluationScope
      context.withDynamicScopes([[:]]) {
        let frame = Context.evaluationScope
        #expect(frame?.parent === parent)
        #expect(frame?.scopes.count == 1)
        if remaining > 1 {
          descend(remaining - 1)
        } else {
          #expect(context.dynamicScopes.count == depth)
        }
      }
      #expect(Context.evaluationScope === parent)
    }

    Context.withFreshEvaluation {
      descend(depth)
      #expect(Context.evaluationScope == nil)
    }
  }

  @Test func linkedDynamicScopesPreserveOrderAndContextIsolation() throws {
    let context = Context(dialect: .draft2020_12)
    let other = Context(dialect: .draft2020_12)
    let url = try #require(URL(string: "https://example.com/scopes"))
    func scope(_ token: String) -> Context.DynamicScope {
      ["item": (document: url, pointer: JSONPointer(tokens: [token]), baseURI: url)]
    }
    func locations(_ context: Context) -> [String] {
      context.dynamicScopes.compactMap { $0["item"]?.pointer.description }
    }

    Context.withFreshEvaluation {
      context.withDynamicScopes([scope("outer-resource"), scope("outer-anchor")]) {
        other.withDynamicScopes([scope("other-context")]) {
          context.withDynamicScopes([scope("inner-resource"), scope("inner-anchor")]) {
            #expect(
              locations(context)
                == ["#/outer-resource", "#/outer-anchor", "#/inner-resource", "#/inner-anchor"]
            )
            #expect(locations(other) == ["#/other-context"])
            let frame = Context.evaluationScope
            Context.withFreshEvaluation {
              #expect(context.dynamicScopes.isEmpty)
              #expect(other.dynamicScopes.isEmpty)
            }
            #expect(Context.evaluationScope === frame)
          }
          #expect(locations(context) == ["#/outer-resource", "#/outer-anchor"])
        }
        #expect(other.dynamicScopes.isEmpty)
      }
      #expect(context.dynamicScopes.isEmpty)
    }
  }

  @Test(arguments: [true, false])
  func reentrantValidationStartsFreshAndRestoresOuterScope(validInstance: Bool) throws {
    let validator = ReentrantFormatValidator()
    let schema = try Schema(
      instance: """
        {
          "$id": "https://example.com/reentrant/main",
          "properties": {
            "numbers": { "$ref": "numberList" },
            "strings": { "$ref": "stringList" }
          },
          "$defs": {
            "genericList": {
              "$id": "genericList",
              "allOf": [
                { "properties": { "gate": { "format": "reentrant" } } },
                { "properties": { "list": { "items": { "$dynamicRef": "#item" } } } }
              ],
              "$defs": { "item": { "$dynamicAnchor": "item" } }
            },
            "numberList": {
              "$id": "numberList",
              "$defs": { "item": { "$dynamicAnchor": "item", "type": "number" } },
              "$ref": "genericList"
            },
            "stringList": {
              "$id": "stringList",
              "$defs": { "item": { "$dynamicAnchor": "item", "type": "string" } },
              "$ref": "genericList"
            }
          }
        }
        """,
      formatValidators: [validator]
    )
    let outer: JSONValue = ["numbers": ["gate": "reenter", "list": [1]]]
    let inner: JSONValue = ["strings": ["list": [validInstance ? "value" : 2]]]
    let baseline = schema.evaluate(outer)
    let innerBaseline = schema.validate(inner)
    #expect(baseline.result.isValid)
    #expect(innerBaseline.isValid == validInstance)

    validator.operation.withLock { operation in
      operation = {
        #expect(schema.validate(inner) == innerBaseline)
        #expect(schema.evaluate(inner).result == innerBaseline)
        return true
      }
    }
    defer { validator.operation.withLock { $0 = nil } }

    #expect(schema.validate(outer) == baseline.result)
    let evaluation = schema.evaluate(outer)
    #expect(evaluation.result == baseline.result)
    // Reentrant public calls are not descendants of the outer projection.
    #expect(evaluationNodes(evaluation) == evaluationNodes(baseline))
    #expect(schema.context.dynamicScopes.isEmpty)
  }

  @Test func recursiveConditionalDoesNotOverwriteItsParent() throws {
    let schema = try Schema(
      instance: """
        {
          "if": { "type": "object" },
          "then": { "properties": { "child": { "$ref": "#" } } },
          "else": { "type": "string" }
        }
        """
    )
    #expect(schema.validate(["child": "leaf"]).isValid)
    let invalid = schema.validate(["child": 1])
    #expect(!invalid.isValid)
    #expect(invalid.errors?.map(\.keyword) == ["then"])
  }

  @Test(arguments: [true, false])
  func remoteContainsMetadataIsLocalToItsSchema(zeroFirst: Bool) throws {
    let schema = try Schema(
      rawSchema: [
        "properties": [
          "optional": ["$ref": "https://example.com/optional"],
          "required": ["$ref": "https://example.com/required"],
        ]
      ],
      context: Context(
        dialect: .draft2020_12,
        remoteSchema: [
          "https://example.com/optional": ["contains": false, "minContains": 0],
          "https://example.com/required": ["contains": false],
        ]
      )
    )
    let optional: JSONValue = ["optional": [1]]
    let required: JSONValue = ["required": [1]]
    if zeroFirst {
      #expect(schema.validate(optional).isValid)
    } else {
      #expect(!schema.validate(required).isValid)
    }
    #expect(schema.validate(optional).isValid)
    let invalid = schema.validate(required)
    #expect(!invalid.isValid)
    let referenceError = try #require(invalid.errors?.first?.errors?.first)
    #expect(referenceError.keyword == "$ref")
    #expect(
      referenceError.errors?.first?.keywordLocation.description
        == "#/properties/required/$ref/contains"
    )
  }

  @Test func concurrentConstructionKeepsVocabularyInheritanceLocal() throws {
    let context = Context(dialect: .draft2020_12)
    let entered = DispatchSemaphore(value: 0)
    let resume = DispatchSemaphore(value: 0)
    let finished = DispatchGroup()
    finished.enter()
    DispatchQueue(label: "EvaluationIsolationTests.vocabulary")
      .async {
        defer { finished.leave() }
        context.withActiveVocabularies(["https://json-schema.org/draft/2020-12/vocab/core"]) {
          entered.signal()
          guard resume.wait(timeout: .now() + 10) == .success else {
            Issue.record("Timed out waiting to resume vocabulary construction")
            return
          }
          do {
            let schema = try Schema(rawSchema: ["type": "string"], context: context)
            #expect(schema.validate(1).isValid)
          } catch {
            Issue.record(error)
          }
        }
      }
    defer {
      resume.signal()
      #expect(finished.wait(timeout: .now() + 10) == .success)
    }
    try #require(entered.wait(timeout: .now() + 10) == .success)
    let schema = try Schema(rawSchema: ["type": "string"], context: context)
    #expect(!schema.validate(1).isValid)
    #expect(context.activeVocabularies == nil)
  }

  private func evaluationNodes(_ evaluation: SchemaEvaluation) -> [ValidationResult] {
    [evaluation.result] + evaluation.children.flatMap(evaluationNodes)
  }
}

private final class ReentrantFormatValidator: FormatValidator {
  let formatName = "reentrant"
  let operation = LockIsolated<(@Sendable () -> Bool)?>(nil)

  func validate(_ value: String) -> Bool {
    let callback = operation.withLock { $0 }
    return callback?() ?? true
  }
}
