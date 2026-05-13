import Foundation
import Testing

@testable import JSONSchema

/// Regression suite for `oneOf` nested error propagation.
///
/// `Keywords.OneOf.validate` historically threw
/// `ValidationIssue.oneOfFailed(errors: [])` with a hard-coded empty array,
/// even though it had already collected per-subschema failures into a
/// `ValidationResultBuilder`. Combined with `makeValidationError` only
/// recently learning to propagate the `errors:` payload of `.oneOfFailed`,
/// downstream consumers (UIs, debuggers, JSON Schema "verbose" output
/// formatters) saw an opaque `oneOf` failure and could not drill down to
/// see *which* of the listed alternatives failed and why.
///
/// These tests pin both the zero-match case (children should surface) and
/// the multi-match case (children should remain empty — the failure is the
/// keyword-level "exactly one" rule, not any individual branch).
struct OneOfNestedErrorsTests {
  /// Zero-match: instance fails *every* `oneOf` branch. The resulting
  /// validation error should expose nested errors for each failing
  /// subschema so consumers can show a useful breakdown.
  @Test
  func oneOfZeroMatchSurfacesPerSubschemaErrors() throws {
    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "oneOf": [
        ["type": "integer", "minimum": 100],
        ["type": "string", "minLength": 5],
      ],
    ]
    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    let result = schema.validate("hi")  // string but too short, also not integer

    #expect(result.isValid == false)

    let oneOfError = try #require(
      result.errors?.first(where: { $0.keyword == "oneOf" }),
      "expected a top-level oneOf error"
    )
    let nested = try #require(
      oneOfError.errors,
      "oneOf error should carry per-subschema errors, not nil"
    )
    #expect(
      nested.isEmpty == false,
      "oneOf error should carry per-subschema errors, not an empty array"
    )
    // Both subschema branches failed; we should see at least one nested
    // error contributing diagnostic context (a `type` mismatch from the
    // integer branch and/or a `minLength` failure from the string branch).
    let nestedKeywords = Set(nested.map { $0.keyword })
    #expect(
      nestedKeywords.contains("type") || nestedKeywords.contains("minLength"),
      "expected per-branch keyword diagnostics; got: \(nestedKeywords)"
    )
  }

  /// Multi-match: instance satisfies *more than one* branch. The collected
  /// builder errors are empty (every branch passed), so the surfaced
  /// `errors:` array stays empty — the failure semantic here is "matched
  /// multiple", not any branch-level verdict.
  @Test
  func oneOfMultiMatchEmitsEmptyChildErrors() throws {
    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "oneOf": [
        ["type": "integer"],
        ["minimum": 0],
      ],
    ]
    let schema = try Schema(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    let result = schema.validate(5)  // matches both branches

    #expect(result.isValid == false)

    let oneOfError = try #require(
      result.errors?.first(where: { $0.keyword == "oneOf" }),
      "expected a top-level oneOf error"
    )
    #expect(
      (oneOfError.errors ?? []).isEmpty,
      "multi-match oneOf failure should carry no per-branch errors"
    )
  }
}
