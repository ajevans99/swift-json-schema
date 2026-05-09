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
}
