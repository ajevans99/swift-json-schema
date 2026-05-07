import Foundation
import Testing

@testable import JSONSchema

/// Regression tests for dynamic-anchor scope tracking, covering scenarios
/// that previously failed because `Schema.validate` keyed dynamic-anchor
/// lookups on `documentURL` (the root document URL) instead of the
/// schema's resource URL (the URL after `$id` resolution). When a single
/// document defines multiple resources via nested `$id`s — common in
/// real-world schemas like OpenAPI 3.1, AsyncAPI, and the JSON Schema
/// 2020-12 meta-schema itself — anchors from sibling resources would
/// leak into each other's evaluation, producing wrong dynamic-ref
/// resolutions.
///
/// Each test corresponds to a JSON Schema 2020-12 `dynamicRef.json`
/// official test-suite group that this fix unblocks. The tests are
/// duplicated here as a focused suite for clarity and faster iteration.
struct DynamicRefScopeTests {

  // MARK: - "after leaving a dynamic scope"
  // Spec: an anchor from a sibling resource (e.g. an `if`-branch resource)
  // must not be visible after that branch returns.

  static let leavingScopeSchema = """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://test.json-schema.org/dynamic-ref-leaving-dynamic-scope/main",
      "if": {
        "$id": "first_scope",
        "$defs": {
          "thingy": { "$dynamicAnchor": "thingy", "type": "number" }
        }
      },
      "then": {
        "$id": "second_scope",
        "$ref": "start",
        "$defs": {
          "thingy": { "$dynamicAnchor": "thingy", "type": "null" }
        }
      },
      "$defs": {
        "start": {
          "$id": "start",
          "$dynamicRef": "inner_scope#thingy"
        },
        "thingy": {
          "$id": "inner_scope",
          "$dynamicAnchor": "thingy",
          "type": "string"
        }
      }
    }
    """

  /// `if/first_scope` defines a `$dynamicAnchor: "thingy"` for `type: number`,
  /// but `if` returns before `$dynamicRef` resolves. Once we're in `then`'s
  /// chain, first_scope's anchor must NOT be in scope. The `$dynamicRef`
  /// should land on `then/second_scope`'s `thingy` (`type: null`).
  @Test func sibling_resource_anchor_not_visible_after_branch_returns() throws {
    let schema = try Schema(instance: Self.leavingScopeSchema)

    // Expected: `then/second_scope`'s `thingy` (type: null) wins.
    let null = try schema.validate(instance: "null")
    #expect(null.isValid, "null should validate against second_scope's `type: null`")

    // A string would match `inner_scope`'s `thingy` (type: string), but
    // the dynamic walk should never reach it — second_scope is in scope.
    let string = try schema.validate(instance: #""a string""#)
    #expect(string.isValid == false, "string should fail against `type: null`")

    // A number would match `first_scope`'s `thingy` (type: number), but
    // first_scope was left when `if` returned — must not be in scope.
    let number = try schema.validate(instance: "42")
    #expect(number.isValid == false, "number should fail; first_scope is not in dynamic scope")
  }

  // MARK: - "$dynamicRef skips over intermediate resources"
  // Spec: when `$ref` chains through multiple resources before reaching a
  // `$dynamicRef`, the outer chain still contributes to the dynamic scope.

  @Test func dynamic_ref_through_intermediate_ref_chain() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://test.json-schema.org/dynamic-ref-skips-intermediate-resource/main",
        "type": "object",
        "properties": {
          "bar-item": { "$ref": "item" }
        },
        "$defs": {
          "bar": {
            "$id": "bar",
            "type": "array",
            "items": { "$ref": "item" },
            "$defs": {
              "item": {
                "$id": "item",
                "type": "object",
                "properties": {
                  "content": { "$dynamicRef": "#content" }
                },
                "$defs": {
                  "defaultContent": {
                    "$dynamicAnchor": "content",
                    "type": "integer"
                  }
                }
              },
              "content": {
                "$dynamicAnchor": "content",
                "type": "string"
              }
            }
          }
        }
      }
      """
    let schema = try Schema(instance: schemaJSON)

    // `bar-item` is `$ref: "item"`. `item`'s `$dynamicRef: "#content"`
    // walks the dynamic scope. Only the `item` resource is in scope (we
    // got there via `$ref` from `main`, not through `bar`), so the
    // bookend is `item`'s `defaultContent` (type: integer).
    let pass = try schema.validate(instance: #"{"bar-item": {"content": 42}}"#)
    #expect(pass.isValid, "integer should validate against `defaultContent`'s `type: integer`")

    let fail = try schema.validate(instance: #"{"bar-item": {"content": "value"}}"#)
    #expect(
      fail.isValid == false,
      "string should fail; `bar`'s `content` (type: string) is not in scope"
    )
  }

  // MARK: - "multiple dynamic paths to the $dynamicRef keyword"
  // Spec: each evaluation path through a schema must compute its own
  // dynamic scope. State from one path must not leak into another.

  static let multiPathSchema = """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://test.json-schema.org/dynamic-ref-with-multiple-paths/main",
      "if": {
        "properties": { "kindOfList": { "const": "numbers" } },
        "required": ["kindOfList"]
      },
      "then": { "$ref": "numberList" },
      "else": { "$ref": "stringList" },
      "$defs": {
        "genericList": {
          "$id": "genericList",
          "properties": {
            "list": { "items": { "$dynamicRef": "#itemType" } }
          },
          "$defs": {
            "defaultItemType": { "$dynamicAnchor": "itemType" }
          }
        },
        "numberList": {
          "$id": "numberList",
          "$defs": {
            "itemType": { "$dynamicAnchor": "itemType", "type": "number" }
          },
          "$ref": "genericList"
        },
        "stringList": {
          "$id": "stringList",
          "$defs": {
            "itemType": { "$dynamicAnchor": "itemType", "type": "string" }
          },
          "$ref": "genericList"
        }
      }
    }
    """

  @Test func per_path_dynamic_scope_recomputation() throws {
    let schema = try Schema(instance: Self.multiPathSchema)

    // `then`-path → numberList's itemType (type: number) wins.
    let numberOK = try schema.validate(instance: #"{"kindOfList": "numbers", "list": [1.1]}"#)
    #expect(numberOK.isValid)
    let numberBad = try schema.validate(instance: #"{"kindOfList": "numbers", "list": ["foo"]}"#)
    #expect(numberBad.isValid == false)

    // `else`-path → stringList's itemType (type: string) wins.
    let stringOK = try schema.validate(instance: #"{"kindOfList": "strings", "list": ["foo"]}"#)
    #expect(stringOK.isValid)
    let stringBad = try schema.validate(instance: #"{"kindOfList": "strings", "list": [1.1]}"#)
    #expect(stringBad.isValid == false)
  }

  // MARK: - "implementation dynamic anchor and reference link"
  // Spec: when a `$ref` chain reaches a resource whose `$dynamicRef` looks
  // for an anchor, the OUTERMOST resource in the dynamic chain that defines
  // a matching `$dynamicAnchor` wins.

  @Test func outermost_resource_anchor_wins_in_chain() throws {
    let schemaJSON = """
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "http://localhost:1234/draft2020-12/strict-extendible.json",
        "$ref": "extendible-dynamic-ref.json",
        "$defs": {
          "elements": {
            "$dynamicAnchor": "elements",
            "properties": { "a": true },
            "required": ["a"],
            "additionalProperties": false
          }
        }
      }
      """

    // The remote schema `extendible-dynamic-ref.json` is loaded by the
    // standard JSON Schema test-suite remote loader — we re-create the
    // remoteSchemas map manually here.
    let extendibleJSON: JSONValue = .object([
      "$schema": .string("https://json-schema.org/draft/2020-12/schema"),
      "$id": .string("http://localhost:1234/draft2020-12/extendible-dynamic-ref.json"),
      "description": .string("extendible array"),
      "$defs": .object([
        "elements": .object([
          "$dynamicAnchor": .string("elements")
        ])
      ]),
      "type": .string("object"),
      "properties": .object([
        "version": .object(["type": .string("number")]),
        "elements": .object([
          "type": .string("array"),
          "items": .object(["$dynamicRef": .string("#elements")]),
        ]),
      ]),
      "required": .array([.string("version"), .string("elements")]),
      "additionalProperties": .boolean(false),
    ])

    let schema = try Schema(
      instance: schemaJSON,
      remoteSchemas: [
        "http://localhost:1234/draft2020-12/extendible-dynamic-ref.json": extendibleJSON
      ]
    )

    // The outermost `$dynamicAnchor: "elements"` (in the parent
    // strict-extendible.json) requires `a` and disallows extras.
    let okPath = try schema.validate(
      instance: #"{"version": 1, "elements": [{"a": 1}]}"#
    )
    #expect(okPath.isValid)

    // Missing `a` in an element — should fail.
    let badElement = try schema.validate(
      instance: #"{"version": 1, "elements": [{"b": 1}]}"#
    )
    #expect(badElement.isValid == false, "element missing required `a` should fail")

    // Missing top-level `version` — should fail (parent extendible schema
    // has `required: ["version", "elements"]` and `additionalProperties: false`).
    let badParent = try schema.validate(instance: #"{"a": true}"#)
    #expect(
      badParent.isValid == false,
      "object missing `version`/`elements` should fail at the parent"
    )
  }
}
