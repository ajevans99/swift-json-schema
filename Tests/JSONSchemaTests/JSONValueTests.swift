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
}
