import Foundation
import Testing

@testable import JSONSchema

/// Regression tests for `$dynamicRef` bookending semantics
/// (JSON Schema 2020-12 §8.2.3.2).
///
/// `$dynamicRef` only triggers dynamic-scope traversal if the reference's
/// initial target resource defines a `$dynamicAnchor` of the same name
/// ("bookending"). Without that bookend, the reference behaves like a
/// regular `$ref` to a same-named `$anchor` — falling through to lexical
/// resolution.
///
/// These tests cover the three "fallback to $ref by anchor" cases from
/// the official `dynamicRef.json` JSON Schema test suite, surfaced as a
/// dedicated suite for clarity. Each test would fail before the bookend
/// fix in `ReferenceResolver.resolveSchema` and passes after.
struct DynamicRefBookendTests {

  /// `$dynamicRef "#items"` lands in a resource (`list`) whose `$defs`
  /// contains `$anchor: "items"` but no `$dynamicAnchor: "items"`. With
  /// no bookend in the target resource, the reference falls back to
  /// `$ref` semantics and resolves to the lexical anchor — which has no
  /// constraints, so any array is valid.
  @Test func fallback_whenNoMatchingDynamicAnchorInResource() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://test.json-schema.org/dynamic-resolution-without-bookend/root",
        "$ref": "list",
        "$defs": {
          "foo": { "$dynamicAnchor": "items", "type": "string" },
          "list": {
            "$id": "list",
            "type": "array",
            "items": { "$dynamicRef": "#items" },
            "$defs": {
              "items": { "$anchor": "items" }
            }
          }
        }
      }
      """
    let result = try Schema(instance: schemaJSON)
      .validate(
        instance: #"["foo", 42]"#
      )
    #expect(result.isValid, "without a bookend $dynamicAnchor, $dynamicRef must fall back to $ref")
  }

  /// Same as above, but the target resource has a `$dynamicAnchor` with a
  /// DIFFERENT name. Still no bookend match → still fall back.
  @Test func fallback_whenDynamicAnchorNameDoesNotMatch() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://test.json-schema.org/unmatched-dynamic-anchor/root",
        "$ref": "list",
        "$defs": {
          "foo": { "$dynamicAnchor": "items", "type": "string" },
          "list": {
            "$id": "list",
            "type": "array",
            "items": { "$dynamicRef": "#items" },
            "$defs": {
              "items": { "$anchor": "items", "$dynamicAnchor": "foo" }
            }
          }
        }
      }
      """
    let result = try Schema(instance: schemaJSON)
      .validate(
        instance: #"["foo", 42]"#
      )
    #expect(result.isValid)
  }

  /// `$dynamicRef "extended#meta"` lands in resource `extended` which has
  /// only `$anchor: "meta"` (no `$dynamicAnchor`). Falls back to lexical
  /// anchor resolution → no recursive validation → any object passes.
  @Test func fallback_whenInitialTargetHasNoDynamicAnchor() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://test.json-schema.org/relative-dynamic-reference-without-bookend/root",
        "$dynamicAnchor": "meta",
        "type": "object",
        "properties": { "foo": { "const": "pass" } },
        "$ref": "extended",
        "$defs": {
          "extended": {
            "$id": "extended",
            "$anchor": "meta",
            "type": "object",
            "properties": { "bar": { "$ref": "bar" } }
          },
          "bar": {
            "$id": "bar",
            "type": "object",
            "properties": { "baz": { "$dynamicRef": "extended#meta" } }
          }
        }
      }
      """
    let result = try Schema(instance: schemaJSON)
      .validate(
        instance: #"{"foo": "pass", "bar": {"baz": {"foo": "fail"}}}"#
      )
    // Without bookend: $dynamicRef resolves lexically to extended#meta
    // which has no `properties` constraint on its target → no recursion
    // back to root → "fail" doesn't violate anything → valid.
    #expect(result.isValid)
  }

  /// Sanity check: when the resource IS bookended, dynamic-scope walking
  /// still works as before (no regression).
  @Test func dynamicScopeWalk_whenBookended() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://test.json-schema.org/typical-dynamic-resolution/root",
        "$ref": "list",
        "$defs": {
          "foo": { "$dynamicAnchor": "items", "type": "string" },
          "list": {
            "$id": "list",
            "type": "array",
            "items": { "$dynamicRef": "#items" },
            "$defs": {
              "items": { "$dynamicAnchor": "items" }
            }
          }
        }
      }
      """
    // The outer dynamic scope's $dynamicAnchor "items" (type: string) wins
    // over the inner empty one. Strings pass; numbers fail.
    let valid = try Schema(instance: schemaJSON)
      .validate(
        instance: #"["foo", "bar"]"#
      )
    #expect(valid.isValid)

    let invalid = try Schema(instance: schemaJSON)
      .validate(
        instance: #"["foo", 42]"#
      )
    #expect(invalid.isValid == false)
  }
}
