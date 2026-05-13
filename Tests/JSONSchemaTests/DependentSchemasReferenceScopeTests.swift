import Foundation
import Testing

@testable import JSONSchema

/// Regression suite for `dependentSchemas` sub-schema construction.
///
/// `Keywords.DependentSchemas.init` historically built each per-property
/// sub-schema with `try? Schema(rawSchema:location:context:)` — omitting
/// `baseURI: context.uri` and using the keyword's own location instead of
/// appending the property key. The missing `baseURI` made the sub-schema
/// fall back to the in-memory placeholder URL, which broke any nested
/// `$ref` inside the sub-schema that was relative to the document root
/// (most visibly: the OpenAPI 3.1 spec's `parameter.dependentSchemas.schema`
/// allOf chain pointing at `#/$defs/parameter/dependentSchemas/...`).
struct DependentSchemasReferenceScopeTests {
  /// A document with a top-level `$id`, a `dependentSchemas` whose
  /// sub-schema uses a `$ref` relative to that `$id`. Pre-fix this would
  /// fail because the `$ref` resolved against the in-memory placeholder
  /// URL instead of the document's `$id`.
  @Test
  func dependentSchemasSubschemaResolvesRelativeRef() throws {
    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://example.com/dep-schemas-ref/main",
      "type": "object",
      "dependentSchemas": [
        "trigger": [
          "$ref": "#/$defs/extra"
        ]
      ],
      "$defs": [
        "extra": [
          "required": ["companion"]
        ]
      ],
    ]
    let context = Context(dialect: .draft2020_12)
    let schema = try Schema(rawSchema: rawSchema, context: context)

    let valid: JSONValue = ["trigger": "yes", "companion": 1]
    #expect(schema.validate(valid).isValid)

    let invalid: JSONValue = ["trigger": "yes"]
    let result = schema.validate(invalid)
    #expect(result.isValid == false)
    // The error message should not mention the in-memory placeholder host.
    let dump = String(describing: result.errors ?? [])
    #expect(!dump.contains("swift-json-schema.invalid"))
  }

  /// Mirrors the OpenAPI 3.1 `parameter.dependentSchemas.schema.allOf`
  /// pattern: a `$ref` from inside the dependent sub-schema's `allOf`
  /// pointing at a sibling `$defs` entry that lives outside the
  /// dependent sub-schema. Pre-fix the `$ref` resolved against the
  /// in-memory placeholder URL, not the document's `$id`.
  @Test
  func dependentSchemasNestedAllOfRefResolves() throws {
    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://example.com/dep-schemas-ref/nested",
      "type": "object",
      "dependentSchemas": [
        "schema": [
          "allOf": [
            ["$ref": "#/$defs/style"]
          ]
        ]
      ],
      "$defs": [
        "style": [
          "properties": [
            "in": ["enum": ["query", "header"]]
          ]
        ]
      ],
    ]
    let context = Context(dialect: .draft2020_12)
    let schema = try Schema(rawSchema: rawSchema, context: context)

    // Triggers the dependent sub-schema (because `schema` is present) and
    // makes the inner `$ref` evaluate against the document's $id, not the
    // in-memory placeholder.
    let valid: JSONValue = ["schema": ["x": 1], "in": "query"]
    let result = schema.validate(valid)
    let dump = String(describing: result.errors ?? [])
    #expect(
      !dump.contains("swift-json-schema.invalid"),
      "errors leaked in-memory placeholder URL: \(dump)"
    )
    #expect(result.isValid, "expected valid; got: \(dump)")
  }

  /// Hardest variant: caller supplies an explicit `baseURI` so the root
  /// schema is *not* registered at the default in-memory placeholder.
  /// With the bug, the dependent sub-schema then claims the in-memory
  /// slot for itself; its local `$defs/x` shadows the root's `$defs/x`,
  /// and a relative `$ref: "#/$defs/x"` resolves to the wrong subschema.
  ///
  /// This flips the validation verdict (not just the error URLs), so it
  /// catches a regression of the baseURI propagation bug regardless of
  /// any future change to the in-memory placeholder string.
  @Test
  func dependentSchemasRefShadowingWithExplicitBaseURI() throws {
    let rawSchema: JSONValue = [
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "dependentSchemas": [
        "trigger": [
          "$defs": [
            "x": ["properties": ["value": ["type": "string"]]]
          ],
          "allOf": [
            ["$ref": "#/$defs/x"]
          ],
        ]
      ],
      "$defs": [
        "x": ["properties": ["value": ["type": "integer"]]]
      ],
    ]
    let context = Context(dialect: .draft2020_12)
    let baseURI = URL(string: "https://example.com/dep-schemas-ref/explicit-base")!
    let schema = try Schema(rawSchema: rawSchema, context: context, baseURI: baseURI)

    // Per spec: dep has no `$id`, so its `$ref: "#/$defs/x"` resolves
    // against the document base URI → root's `$defs/x` (integer).
    let validInstance: JSONValue = ["trigger": 1, "value": 5]
    let validResult = schema.validate(validInstance)
    #expect(
      validResult.isValid,
      "expected valid (root's #/$defs/x is integer; value=5 matches); got: \(String(describing: validResult.errors ?? []))"
    )

    let invalidInstance: JSONValue = ["trigger": 1, "value": "not-an-integer"]
    let invalidResult = schema.validate(invalidInstance)
    #expect(invalidResult.isValid == false, "expected invalid (value should be integer)")
  }
}
