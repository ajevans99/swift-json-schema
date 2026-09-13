import Foundation
import JSONSchema
import Testing

struct JSONValueTests {
  @Test func decodeNil() throws {
    let jsonString = """
      {
        "const": null
      }
      """
    let jsonValue = try JSONDecoder().decode(JSONValue.self, from: jsonString.data(using: .utf8)!)
    #expect(jsonValue == ["const": .null])
  }

  @Test
  func mergeObjects() {
    var a: JSONValue = .object([
      "type": .string("object"),
      "properties": .object([
        "to": .object(["type": .string("string")])
      ]),
    ])

    let b: JSONValue = .object([
      "properties": .object([
        "from": .object(["type": .string("string")])
      ])
    ])

    a.merge(b)

    #expect(a.object?["type"] == .string("object"))
    #expect(a.object?["properties"]?.object?.count == 2)
    #expect(a.object?["properties"]?.object?["to"] != nil)
    #expect(a.object?["properties"]?.object?["from"] != nil)
  }

  @Test
  func mergeArrays() {
    var a: JSONValue = .array([.string("a")])
    let b: JSONValue = .array([.string("b"), .string("c")])

    a.merge(b)

    #expect(a == .array([.string("a"), .string("b"), .string("c")]))
  }

  @Test
  func mergeScalarPreserve() {
    var a: JSONValue = .string("keep me")
    let b: JSONValue = .string("overwrite me")

    a.merge(b)

    #expect(a == .string("keep me"))  // scalar is preserved
  }

  @Test
  func mergeNullGetsOverwritten() {
    var a: JSONValue = .null
    let b: JSONValue = .boolean(true)

    a.merge(b)

    #expect(a == .boolean(true))
  }

  @Test
  func deeplyNestedMerge() {
    var a: JSONValue = .object([
      "outer": .object([
        "inner": .object([
          "a": .string("a")
        ])
      ])
    ])

    let b: JSONValue = .object([
      "outer": .object([
        "inner": .object([
          "b": .string("b")
        ])
      ])
    ])

    a.merge(b)

    let inner = a.object?["outer"]?.object?["inner"]?.object
    #expect(inner?["a"] == .string("a"))
    #expect(inner?["b"] == .string("b"))
  }

  @Test
  func stringEqualityIsScalarExact() {
    let composed: JSONValue = .string("ä")  // U+00E4
    let decomposed: JSONValue = .string("a\u{0308}")  // U+0061 U+0308

    #expect(composed != decomposed)
    #expect(JSONValue.string("hello") == JSONValue.string("hello"))
  }

  // MARK: - Determinism (#149)

  @Test
  func serializedPreservesObjectKeyInsertionOrder() throws {
    let value: JSONValue = [
      "$id": "https://example.com/schema",
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer"],
        "email": ["type": "string"],
      ],
      "required": .array([.string("name"), .string("age")]),
    ]

    let encoded = try value.serialized()

    let expected =
      "{\"$id\":\"https://example.com/schema\",\"type\":\"object\",\"properties\":"
      + "{\"name\":{\"type\":\"string\"},\"age\":{\"type\":\"integer\"},\"email\":{\"type\":\"string\"}},"
      + "\"required\":[\"name\",\"age\"]}"
    #expect(encoded == expected)
  }

  @Test
  func serializedIsByteStableAcrossRepeatedCalls() throws {
    let value: JSONValue = [
      "type": "object",
      "properties": [
        "alpha": ["type": "string"],
        "beta": ["type": "integer"],
        "gamma": ["type": "boolean"],
      ],
      "additionalProperties": false,
    ]

    let outputs: [String] = try (0 ..< 10).map { _ in try value.serialized() }
    let first = outputs[0]
    for run in outputs.dropFirst() {
      #expect(run == first, "Encoded bytes should be identical across repeated calls")
    }
  }

  @Test
  func objectEqualityIsOrderInsensitive() {
    let a: JSONValue = ["x": 1, "y": 2]
    let b: JSONValue = ["y": 2, "x": 1]
    // JSON objects are unordered for equality even though we now preserve
    // insertion order for emission.
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
  }

  @Test
  func serializedPrettyPrintedRespectsIndent() throws {
    let value: JSONValue = ["a": 1, "b": [.integer(2), .integer(3)]]
    let encoded = try value.serialized(options: .pretty)
    let expected = """
      {
        "a" : 1,
        "b" : [
          2,
          3
        ]
      }
      """
    #expect(encoded == expected)
  }

  @Test
  func nonConformingFloatsAreRejectedBeforeSerialization() {
    for value in [Double.nan, Double.infinity, -Double.infinity] {
      #expect(throws: (any Error).self) {
        _ = try JSONNumberLiteral(value)
      }
    }
  }

  @Test
  func serializedPreservesNumberTokensBeyondSwiftNumericRanges() throws {
    let json = #"{"x":1e1000,"y":9.270,"z":-0,"small":1e-1000}"#
    #expect(try JSONValue.parse(json).serialized() == json)
  }

  @Test func codableInteroperabilityPreservesRepresentableDecimalValues() throws {
    let value = try JSONValue.parse("9.270000000000000001")
    let data = try JSONEncoder().encode(value)
    #expect(try JSONValue.parse(data) == value)
    #expect(try JSONDecoder().decode(JSONValue.self, from: data) == value)
  }

  @Test func codableEncodingRejectsUnrepresentableNumbersInsteadOfRounding() throws {
    for text in ["1e1000", "1e-1000", "1234567890123456789012345678901234567890123456789"] {
      let value = try JSONValue.parse(text)
      #expect(throws: EncodingError.self) {
        _ = try JSONEncoder().encode(value)
      }
    }
  }
}
