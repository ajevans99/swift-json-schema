import Foundation
import Testing

@testable import JSONSchema

/// Regression tests for annotation propagation from in-place applicators
/// (`allOf`, `anyOf`, `dependentSchemas`).
///
/// JSON Schema 2020-12 §7.7 says annotations from *failing* keywords must
/// not be collected, and §10.2.1.1 / §10.2.1.2 / §10.2.2.4 specify that
/// these in-place applicators collect annotations only from successful
/// (matching) subschemas. Leaking annotations from failing branches causes
/// sibling `unevaluatedProperties` to incorrectly treat properties
/// addressed by a non-applicable branch as evaluated.
///
/// Each test below is constructed so it FAILS on `main` (with the leak)
/// and PASSES on this PR (with the fix). For tests where the overall
/// validation result is invalid in both cases, we assert on the *shape*
/// of the resulting error tree rather than on `isValid`.
struct AnnotationLeakageTests {

  // MARK: - anyOf

  /// One passing branch + one failing branch. Both branches' `properties`
  /// keywords would syntactically address different keys; only the passing
  /// branch's annotation should propagate. With the leak bug, the failing
  /// branch's `properties` annotation also propagates and incorrectly
  /// suppresses an `unevaluatedProperties` failure.
  @Test func anyOf_doesNotLeakAnnotationsFromFailingBranches() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "anyOf": [
          { "properties": { "a": { "type": "string" } }, "required": ["a"] },
          { "properties": { "b": { "type": "string" } }, "required": ["nope"] }
        ],
        "unevaluatedProperties": false
      }
      """
    let result = try Schema(instance: schemaJSON)
      .validate(
        instance: #"{"a": "x", "b": "y"}"#
      )
    // With fix: branch 2 fails → its `properties: { b }` annotation does NOT
    // propagate. `b` is then unevaluated → validation fails.
    // With leak: branch 2's annotation leaks → `b` appears evaluated →
    // validation incorrectly passes.
    #expect(result.isValid == false)
    #expect(
      anyError(in: result, keyword: "unevaluatedProperties", instanceLocation: "#/b"),
      "expected an unevaluatedProperties error for `/b`"
    )
  }

  // MARK: - allOf

  /// A failing `allOf` subschema with a `properties` keyword. Sibling
  /// `unevaluatedProperties: false` should still see the property as
  /// unevaluated even though the property name is structurally present
  /// in the failing subschema's `properties`. With the leak, the
  /// `unevaluatedProperties` error never fires; with the fix, it does.
  /// Validation is invalid in both cases (the `allOf` assertion fails),
  /// so we assert on error *shape*: the presence of an
  /// `unevaluatedProperties` error.
  @Test func allOf_doesNotLeakAnnotationsFromFailingBranches() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "allOf": [
          { "properties": { "a": { "type": "string" } }, "required": ["nope"] }
        ],
        "unevaluatedProperties": false
      }
      """
    let result = try Schema(instance: schemaJSON).validate(instance: #"{"a": "x"}"#)
    #expect(result.isValid == false)
    #expect(
      anyError(in: result, keyword: "unevaluatedProperties", instanceLocation: "#/a"),
      "expected an unevaluatedProperties error for `/a`; without the fix, the `allOf` branch's `properties` annotation leaks and suppresses this error"
    )
  }

  // MARK: - dependentSchemas

  /// A `dependentSchemas` subschema that fires (its trigger key is present)
  /// but fails (`required: ["nope"]`). The failing subschema's `properties`
  /// annotation should not propagate — otherwise a sibling
  /// `unevaluatedProperties: false` would incorrectly let the property
  /// through. Validation is invalid in both cases, so we assert on shape.
  @Test func dependentSchemas_doesNotLeakAnnotationsFromFailingBranches() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "dependentSchemas": {
          "trigger": {
            "properties": { "extra": true },
            "required": ["nope"]
          }
        },
        "unevaluatedProperties": false
      }
      """
    let result = try Schema(instance: schemaJSON)
      .validate(
        instance: #"{"trigger": 1, "extra": "leaked?"}"#
      )
    #expect(result.isValid == false)
    #expect(
      anyError(in: result, keyword: "unevaluatedProperties", instanceLocation: "#/extra"),
      "expected an unevaluatedProperties error for `/extra`; without the fix, the failing dependent subschema's `properties: { extra }` annotation leaks"
    )
  }
}

// MARK: - Helpers

/// Walks the recursive `errors` tree of a `ValidationResult` looking for an
/// `unevaluatedProperties` failure that includes a leaf at `instanceLocation`
/// (the per-property failure inside the keyword's nested errors).
private func anyError(
  in result: ValidationResult,
  keyword: String,
  instanceLocation: String
) -> Bool {
  func walk(_ errs: [ValidationError]?) -> Bool {
    guard let errs else { return false }
    for e in errs {
      if e.keyword == keyword
        && (e.errors ?? []).contains(where: { $0.instanceLocation.description == instanceLocation })
      {
        return true
      }
      if walk(e.errors) { return true }
    }
    return false
  }
  return walk(result.errors)
}
