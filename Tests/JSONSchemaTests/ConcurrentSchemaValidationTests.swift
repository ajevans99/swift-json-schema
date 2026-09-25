import Dispatch
import Foundation
import JSONSchema
import Testing

struct ConcurrentSchemaValidationTests {
  @Test func concurrentColdReferencesValidateIndependently() throws {
    let schema = try Schema(
      instance: """
        {
          "$ref": "#/$defs/text",
          "$defs": { "text": { "type": "string", "minLength": 2 } }
        }
        """
    )
    DispatchQueue.concurrentPerform(iterations: 32) { index in
      let valid = index.isMultiple(of: 2)
      let result = schema.validate(valid ? "hello" : 42)
      #expect(result.isValid == valid)
      if !valid {
        #expect(
          leafErrors(result.errors ?? []).map(\.keywordLocation.description) == ["#/$ref/type"]
        )
      }
    }
  }

  @Test func referenceValidationDoesNotHoldTheResolutionLock() throws {
    let gate = PausingFormatValidator()
    let schema = try Schema(
      instance: """
        {
          "$ref": "#/$defs/text",
          "$defs": { "text": { "type": "string", "format": "pause-validation" } }
        }
        """,
      formatValidators: [gate]
    )
    let (resumed, overlapping) = try overlap(
      schema: schema,
      first: "first",
      second: "second",
      gate: gate
    )
    #expect(resumed.isValid)
    #expect(overlapping.isValid)
  }

  @Test(arguments: [true, false])
  func concurrentConditionalsMatchSerialValidation(validInstances: Bool) throws {
    let gate = PausingFormatValidator()
    let schema = try Schema(
      instance: """
        {
          "if": { "pattern": "^number:" },
          "then": { "pattern": "^number:ok$", "format": "pause-validation" },
          "else": { "pattern": "^string:ok$" }
        }
        """,
      formatValidators: [gate]
    )
    let first: JSONValue = validInstances ? "number:ok" : "number:bad"
    let second: JSONValue = validInstances ? "string:ok" : "string:bad"
    let firstBaseline = schema.validate(first)
    let secondBaseline = schema.validate(second)
    #expect(firstBaseline.isValid == validInstances)
    #expect(secondBaseline.isValid == validInstances)
    if !validInstances {
      #expect(
        leafErrors(firstBaseline.errors ?? []).map(\.keywordLocation.description)
          == ["#/then/pattern"]
      )
      #expect(
        leafErrors(secondBaseline.errors ?? []).map(\.keywordLocation.description)
          == ["#/else/pattern"]
      )
    }

    let (resumed, overlapping) = try overlap(
      schema: schema,
      first: first,
      second: second,
      gate: gate
    )
    #expect(resumed == firstBaseline)
    #expect(overlapping == secondBaseline)
  }

  @Test(arguments: [true, false])
  func concurrentDynamicReferencesMatchSerialValidation(validInstances: Bool) throws {
    let gate = PausingFormatValidator()
    let schema = try Schema(
      instance: """
        {
          "$id": "https://example.com/concurrent/main",
          "properties": {
            "numbers": { "$ref": "numberList" },
            "strings": { "$ref": "stringList" }
          },
          "$defs": {
            "genericList": {
              "$id": "genericList",
              "allOf": [
                { "properties": { "gate": { "format": "pause-validation" } } },
                { "properties": { "list": { "items": { "$dynamicRef": "#itemType" } } } }
              ],
              "$defs": { "defaultItemType": { "$dynamicAnchor": "itemType" } }
            },
            "numberList": {
              "$id": "numberList",
              "$defs": { "itemType": { "$dynamicAnchor": "itemType", "type": "number" } },
              "$ref": "genericList"
            },
            "stringList": {
              "$id": "stringList",
              "$defs": { "itemType": { "$dynamicAnchor": "itemType", "type": "string" } },
              "$ref": "genericList"
            }
          }
        }
        """,
      formatValidators: [gate]
    )
    let first: JSONValue = [
      "numbers": ["gate": "pause", "list": [validInstances ? 1 : "wrong"]]
    ]
    let second: JSONValue = [
      "strings": ["list": [validInstances ? "value" : 2]]
    ]
    let firstBaseline = schema.validate(first)
    let secondBaseline = schema.validate(second)
    #expect(firstBaseline.isValid == validInstances)
    #expect(secondBaseline.isValid == validInstances)
    if !validInstances {
      for (result, property, resource) in [
        (firstBaseline, "numbers", "numberList"),
        (secondBaseline, "strings", "stringList"),
      ] {
        let error = try #require(leafErrors(result.errors ?? []).first)
        #expect(error.keyword == "type")
        #expect(error.instanceLocation.description == "#/\(property)/list/0")
        #expect(
          error.keywordLocation.description
            == "#/properties/\(property)/$ref/$ref/allOf/1/properties/list/items/$dynamicRef/type"
        )
        #expect(
          error.absoluteKeywordLocation?.absoluteString
            == "https://example.com/concurrent/\(resource)#/$defs/\(resource)/$defs/itemType/type"
        )
      }
    }

    let (resumed, overlapping) = try overlap(
      schema: schema,
      first: first,
      second: second,
      gate: gate
    )
    #expect(resumed == firstBaseline)
    #expect(overlapping == secondBaseline)
  }

  private func overlap(
    schema: Schema,
    first: JSONValue,
    second: JSONValue,
    gate: PausingFormatValidator
  ) throws -> (ValidationResult, ValidationResult) {
    let worker = ValidationWorker()
    gate.arm()
    // A dedicated queue avoids blocking a cooperative Swift concurrency executor.
    DispatchQueue(label: "ConcurrentSchemaValidationTests.worker")
      .async {
        worker.finish(schema.validate(first))
      }
    defer {
      gate.release()
      #expect(worker.waitForResult() != nil, "The validation worker must finish during cleanup")
    }
    try #require(gate.waitUntilPaused(), "The first validation must reach the format checkpoint")

    // The first call has entered its branch/resource but cannot leave it until
    // the opposite path finishes. Both calls retain the same Schema/Context.
    let overlapping = schema.validate(second)
    gate.release()
    let resumed = try #require(worker.waitForResult(), "The paused validation must finish")
    return (resumed, overlapping)
  }

  private func leafErrors(_ errors: [ValidationError]) -> [ValidationError] {
    errors.flatMap { error in
      guard let children = error.errors, !children.isEmpty else { return [error] }
      return leafErrors(children)
    }
  }
}

// Mutable state is lock-protected; semaphore waits are bounded and timeouts fail
// the test rather than silently accepting an uncoordinated validation.
private final class PausingFormatValidator: FormatValidator, @unchecked Sendable {
  let formatName = "pause-validation"
  private let lock = NSLock()
  private var armed = false
  private let paused = DispatchSemaphore(value: 0)
  private let resume = DispatchSemaphore(value: 0)

  func arm() {
    lock.withLock { armed = true }
  }

  func validate(_ value: String) -> Bool {
    let shouldPause = lock.withLock {
      let result = armed
      armed = false
      return result
    }
    guard shouldPause else { return true }
    paused.signal()
    guard resume.wait(timeout: .now() + 10) == .success else {
      Issue.record("Timed out waiting to resume the paused validation")
      return false
    }
    return true
  }

  func waitUntilPaused() -> Bool {
    paused.wait(timeout: .now() + 10) == .success
  }

  func release() {
    resume.signal()
  }
}

private final class ValidationWorker: @unchecked Sendable {
  private let lock = NSLock()
  private var result: ValidationResult?
  private let finished = DispatchGroup()

  init() {
    finished.enter()
  }

  func finish(_ result: ValidationResult) {
    lock.withLock { self.result = result }
    finished.leave()
  }

  func waitForResult() -> ValidationResult? {
    guard finished.wait(timeout: .now() + 10) == .success else { return nil }
    return lock.withLock { result }
  }
}
