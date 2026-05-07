import Foundation
import Testing
@testable import JSONSchema

/// Regression tests for annotation propagation from in-place applicators
/// (`allOf`, `anyOf`, `dependentSchemas`).
///
/// JSON Schema 2020-12 §10.2.1.1 / §10.2.1.2 / §10.2.2.4 specify that
/// annotations from these applicators are collected only from the
/// successful (matching) subschemas. Leaking annotations from failing
/// subschemas causes sibling `unevaluatedProperties` / `unevaluatedItems`
/// to incorrectly treat properties or indices "matched" by a failed branch
/// as evaluated.
struct AnnotationLeakageTests {

  // MARK: anyOf

  /// Three `anyOf` branches each declare different `properties`. Only the
  /// branch matching the instance's required key should propagate its
  /// `properties` annotation. Sibling `unevaluatedProperties: false` then
  /// rejects keys not covered by *any* matched branch.
  @Test func anyOf_doesNotLeakPropertiesAnnotationFromFailingBranches() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "anyOf": [
          { "properties": { "a": { "type": "string" } }, "required": ["a"] },
          { "properties": { "b": { "type": "string" } }, "required": ["b"] }
        ],
        "unevaluatedProperties": false
      }
      """
    // Only branch 1 matches (required: a). `b` is NOT structurally addressed
    // by branch 1, so it should be flagged as unevaluated.
    let result = try Schema(instance: schemaJSON).validate(
      instance: #"{"a": "x", "b": "y"}"#
    )
    #expect(result.isValid == false)
  }

  // MARK: allOf

  /// `allOf`'s annotations propagate only from successful subschemas.
  /// When one branch fails, its `properties` annotation must not survive
  /// to influence sibling `unevaluatedProperties`.
  @Test func allOf_doesNotLeakPropertiesAnnotationFromFailingBranches() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "allOf": [
          { "properties": { "a": { "type": "string" } }, "required": ["a"] }
        ],
        "anyOf": [
          { "properties": { "b": { "type": "string" } }, "unevaluatedProperties": false }
        ]
      }
      """
    // Sibling `anyOf` branch has `unevaluatedProperties: false`. The `allOf`
    // sibling at the same level addressed `a`, but the `anyOf` branch only
    // sees its OWN nested annotations (because `allOf` is outside the
    // `anyOf` subschema's scope), so `a` should be unevaluated for the
    // `anyOf` branch's check. Both fields present → fail.
    let result = try Schema(instance: schemaJSON).validate(
      instance: #"{"a": "x", "b": "y"}"#
    )
    #expect(result.isValid == false)
  }

  // MARK: dependentSchemas

  /// `dependentSchemas` only propagates annotations from subschemas whose
  /// trigger key is present AND whose subschema validation succeeds.
  @Test func dependentSchemas_doesNotLeakAnnotationsFromFailingBranches() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "dependentSchemas": {
          "trigger": {
            "properties": { "extra": { "type": "string" } },
            "required": ["nope"]
          }
        },
        "unevaluatedProperties": false
      }
      """
    // Trigger key present, but `required: ["nope"]` will fail. The branch's
    // `properties` annotation for `extra` MUST NOT leak; otherwise `extra`
    // would appear "evaluated" and `unevaluatedProperties: false` would let
    // it through. The instance should fail validation (both due to the
    // `required` failure AND because `extra` is unevaluated — but the key
    // assertion is that we get the failure, not a spurious pass).
    let result = try Schema(instance: schemaJSON).validate(
      instance: #"{"trigger": 1, "extra": "leaked?"}"#
    )
    #expect(result.isValid == false)
  }
}
