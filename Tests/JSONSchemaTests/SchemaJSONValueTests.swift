import Foundation
import Testing

@testable import JSONSchema

@Suite("Schema.jsonValue accessor (#161)")
struct SchemaJSONValueTests {

  // MARK: - BooleanSchema

  @Test func trueBooleanSchemaRoundtripsToBooleanJSONValue() throws {
    let schema = try Schema(rawSchema: .boolean(true), context: Context(dialect: .draft2020_12))
    #expect(schema.jsonValue == .boolean(true))
  }

  @Test func falseBooleanSchemaRoundtripsToBooleanJSONValue() throws {
    let schema = try Schema(rawSchema: .boolean(false), context: Context(dialect: .draft2020_12))
    #expect(schema.jsonValue == .boolean(false))
  }

  // MARK: - ObjectSchema — round-trip equivalence

  /// `Schema(rawSchema: x).jsonValue == x`, modulo:
  ///
  /// - Object key order matches the dialect's keyword registration order
  ///   (which JSONValue's order-insensitive `==` ignores anyway).
  /// - Unknown / out-of-dialect keys are dropped — the schema only
  ///   re-emits the keywords it actually recognized. We test with input
  ///   that uses only well-known keywords so this difference doesn't
  ///   show up.
  @Test func objectSchemaRoundtripsToOriginalJSONValue() throws {
    let raw: JSONValue = [
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer", "minimum": 0],
      ],
      "required": .array([.string("name")]),
    ]
    let schema = try Schema(rawSchema: raw, context: Context(dialect: .draft2020_12))
    #expect(schema.jsonValue == raw)
  }

  // MARK: - Key ordering matches dialect order

  @Test func objectSchemaJSONValueKeysAreInDialectOrder() throws {
    // Dialect ordering puts `$id` early (Identifier keyword) and `type`
    // later. Even if the source declares them in reverse, jsonValue
    // emits them in the dialect's order.
    let raw: JSONValue = [
      "type": "string",
      "$id": "https://example.com/s",
      "minLength": 5,
    ]
    let schema = try Schema(rawSchema: raw, context: Context(dialect: .draft2020_12))
    guard case .object(let dict) = schema.jsonValue else {
      Issue.record("Expected an object jsonValue")
      return
    }
    let keys = Array(dict.keys)
    let idIdx = keys.firstIndex(of: "$id") ?? Int.max
    let typeIdx = keys.firstIndex(of: "type") ?? Int.max
    let minLenIdx = keys.firstIndex(of: "minLength") ?? Int.max
    #expect(idIdx < typeIdx, "$id should come before type")
    #expect(typeIdx < minLenIdx, "type should come before minLength")
  }

  // MARK: - Serialization stability

  @Test func serializedJSONValueIsByteStableAcrossCalls() throws {
    let raw: JSONValue = [
      "type": "object",
      "properties": [
        "a": ["type": "string"],
        "b": ["type": "integer"],
      ],
    ]
    let schema = try Schema(rawSchema: raw, context: Context(dialect: .draft2020_12))

    let outputs = try (0 ..< 5).map { _ in try schema.jsonValue.serialized() }
    let first = outputs[0]
    for run in outputs.dropFirst() {
      #expect(run == first)
    }
  }

  // MARK: - ValidationResult.jsonValue

  @Test func validationResultJSONValueMatchesEncodableShape() throws {
    let raw: JSONValue = [
      "type": "string",
      "minLength": 5,
    ]
    let schema = try Schema(rawSchema: raw, context: Context(dialect: .draft2020_12))
    let result = schema.validate(.string("abc"))
    #expect(result.isValid == false)

    let json = result.jsonValue
    guard case .object(let dict) = json else {
      Issue.record("Expected an object")
      return
    }

    // Encode-contract field set: valid, keywordLocation, instanceLocation,
    // (optional) absoluteKeywordLocation, errors, annotations.
    #expect(dict["valid"] == .boolean(false))
    #expect(dict["keywordLocation"] != nil)
    #expect(dict["instanceLocation"] != nil)
    #expect(dict["errors"] != nil)
  }

  /// The new `jsonValue` accessor and the existing `Encodable` conformance
  /// emit the same logical shape. We compare structurally rather than by
  /// bytes because `JSONEncoder` may reorder keys.
  @Test func validationResultJSONValueMatchesEncodableLogically() throws {
    let raw: JSONValue = ["type": "integer"]
    let schema = try Schema(rawSchema: raw, context: Context(dialect: .draft2020_12))
    let result = schema.validate(.string("not an int"))

    // Round-trip the Encodable form back to a JSONValue so we can compare
    // (JSONValue's `==` is order-insensitive on objects).
    let encoded = try JSONEncoder().encode(result)
    let viaCodable = try JSONValue.parse(encoded)

    #expect(result.jsonValue == viaCodable)
  }

  @Test func validationResultJSONValuePreservesSuccessfulAnnotations() throws {
    let baseURI = try #require(URL(string: "https://example.com/annotated"))
    let raw: JSONValue = [
      "$id": "https://example.com/annotated",
      "title": "outer",
      "properties": [
        "x": ["title": "x-title", "type": "string"],
        "y": ["title": "y-title", "type": "string"],
      ],
    ]
    let schema = try Schema(
      rawSchema: raw,
      context: Context(dialect: .draft2020_12),
      baseURI: baseURI
    )
    let instance: JSONValue = ["y": "second", "x": "first"]
    let result = schema.validate(instance, at: JSONPointer(tokens: ["payload"]))
    #expect(result.isValid)

    // AnnotationContainer supplies relative locations only. Its optional
    // absolute locations are nil and must be omitted by both serializers.
    let expected: JSONValue = [
      "valid": true,
      "keywordLocation": "",
      "absoluteKeywordLocation": "https://example.com/annotated#",
      "instanceLocation": "/payload",
      "annotations": [
        [
          "keywordLocation": "/title",
          "instanceLocation": "/payload",
          "annotation": "outer",
        ],
        [
          "keywordLocation": "/properties/y/title",
          "instanceLocation": "/payload/y",
          "annotation": "y-title",
        ],
        [
          "keywordLocation": "/properties/x/title",
          "instanceLocation": "/payload/x",
          "annotation": "x-title",
        ],
        [
          "keywordLocation": "/properties",
          "instanceLocation": "/payload",
          "annotation": ["y", "x"],
        ],
      ],
    ]
    let viaCodable = try JSONValue.parse(JSONEncoder().encode(result))
    #expect(result.jsonValue == viaCodable)
    #expect(result.jsonValue == expected)
  }

  @Test func validationResultJSONValuePreservesNestedReferenceAndCompositionErrors() throws {
    let baseURI = try #require(URL(string: "https://example.com/choices"))
    let raw: JSONValue = [
      "$id": "https://example.com/choices",
      "$defs": [
        "choice": [
          "oneOf": [
            ["type": "string", "minLength": 3],
            ["type": "string", "pattern": "^A"],
          ]
        ]
      ],
      "properties": [
        "value": ["$ref": "#/$defs/choice"]
      ],
    ]
    let schema = try Schema(
      rawSchema: raw,
      context: Context(dialect: .draft2020_12),
      baseURI: baseURI
    )
    let result = schema.validate(["value": "hi"])
    #expect(result.isValid == false)

    // Relative locations follow the reference; absolute locations retain
    // the definition's path. Both failing oneOf branches must survive.
    let minLengthError: JSONValue = [
      "keyword": "minLength",
      "message": "String 'hi' is shorter than minimum length of 3",
      "keywordLocation": "/properties/value/$ref/oneOf/0/minLength",
      "absoluteKeywordLocation": "https://example.com/choices#/$defs/choice/oneOf/0/minLength",
      "instanceLocation": "/value",
    ]
    let patternError: JSONValue = [
      "keyword": "pattern",
      "message": "String 'hi' does not match pattern '^A'",
      "keywordLocation": "/properties/value/$ref/oneOf/1/pattern",
      "absoluteKeywordLocation": "https://example.com/choices#/$defs/choice/oneOf/1/pattern",
      "instanceLocation": "/value",
    ]
    let oneOfError: JSONValue = [
      "keyword": "oneOf",
      "message": .string(
        "Failed to satisfy exactly one schema: String 'hi' is shorter than minimum length of 3; "
          + "String 'hi' does not match pattern '^A'"
      ),
      "keywordLocation": "/properties/value/$ref/oneOf",
      "absoluteKeywordLocation": "https://example.com/choices#/$defs/choice/oneOf",
      "instanceLocation": "/value",
      "errors": .array([minLengthError, patternError]),
    ]
    let referenceError: JSONValue = [
      "keyword": "$ref",
      "message": "Validation failed during reference validation '#/$defs/choice'",
      "keywordLocation": "/properties/value/$ref",
      "absoluteKeywordLocation": "https://example.com/choices#/properties/value/$ref",
      "instanceLocation": "/value",
      "errors": .array([oneOfError]),
    ]
    let propertiesError: JSONValue = [
      "keyword": "properties",
      "message": "Validation failed for keyword 'properties'",
      "keywordLocation": "/properties",
      "absoluteKeywordLocation": "https://example.com/choices#/properties",
      "instanceLocation": "",
      "errors": .array([referenceError]),
    ]
    let expected: JSONValue = [
      "valid": false,
      "keywordLocation": "",
      "absoluteKeywordLocation": "https://example.com/choices#",
      "instanceLocation": "",
      "errors": .array([propertiesError]),
      "annotations": [
        [
          "keywordLocation": "/properties",
          "instanceLocation": "",
          "annotation": ["value"],
        ]
      ],
    ]
    let viaCodable = try JSONValue.parse(JSONEncoder().encode(result))
    #expect(result.jsonValue == viaCodable)
    #expect(result.jsonValue == expected)
  }
}
