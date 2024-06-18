import JSONSchema
import Testing

@testable import JSONResultBuilders

struct JSONValueBuilderTests {
  @Test func variadicParameter() {
    @JSONValueBuilder var object: JSONValueRepresentable { JSONStringValue(string: "Hello") }

    // Single expression should not build to array
    #expect(object.value == .string("Hello"))

    @JSONValueBuilder var array: JSONValueRepresentable {
      JSONStringValue(string: "Hello")
      JSONStringValue(string: "World")
    }

    // Two or more expressions should build to array
    #expect(array.value == .array([.string("Hello"), .string("World")]))
  }

  @Test func typeHints() {
    @JSONValueBuilder var example: JSONValueRepresentable {
      "Hello"
      1
      false
      2.0
      nil

      ["a", "b"]
      [1, 2, 3]
      [1.0, 2.0, 3.0]
      [true, false, true]
      [nil, nil]
      [
        JSONStringValue(string: "a"), JSONIntegerValue(integer: 1), JSONNumberValue(number: 1.0),
        JSONBooleanValue(boolean: true), JSONNullValue(),
      ]
      ["c": 1]
      ["d": 2.0]
      ["e": nil]
      ["f": true]
      ["g": "h"]
      [
        "i": JSONStringValue(string: "a"), "j": JSONIntegerValue(integer: 1),
        "k": JSONNumberValue(number: 1.0), "l": JSONBooleanValue(boolean: true),
      ]
    }

    #expect(
      example.value == [
        .string("Hello"), .integer(1), .boolean(false), .number(2.0), .null,
        .array([.string("a"), .string("b")]), .array([.integer(1), .integer(2), .integer(3)]),
        .array([.number(1.0), .number(2.0), .number(3.0)]),
        .array([.boolean(true), .boolean(false), .boolean(true)]), .array([.null, .null]),
        .array([.string("a"), .integer(1), .number(1.0), .boolean(true), .null]),
        .object(["c": .integer(1)]), .object(["d": .number(2.0)]), .object(["e": .null]),
        .object(["f": .boolean(true)]), .object(["g": .string("h")]),
        .object(["i": .string("a"), "j": .integer(1), "k": .number(1.0), "l": .boolean(true)]),
      ]
    )
  }

  @Test func composition() {
    @JSONValueBuilder var hello: JSONValueRepresentable { "Hello" }

    @JSONValueBuilder var world: JSONValueRepresentable { "World" }

    @JSONValueBuilder var together: JSONValueRepresentable {
      hello
      world
    }

    #expect(together.value == .array([.string("Hello"), .string("World")]))
  }

  @Test func array() {
    let strings = [
      "Steam Engine", "Factory System", "Mass Production", "Urbanization", "Textile Industry",
      "Railroads", "Mechanization", "Labor Unions", "Child Labor", "Industrialization",
    ]
    @JSONValueBuilder var example: JSONValueRepresentable { for string in strings { string } }

    #expect(example.value == .array(strings.map { .string($0) }))
  }

  @Test(arguments: [true, false]) func optional(_ bool: Bool) {
    @JSONValueBuilder var example: JSONValueRepresentable { if bool { "Hello" } }

    #expect(example.value == (bool ? .string("Hello") : .null))
  }

  @Test(arguments: [true, false]) func either(_ bool: Bool) {
    @JSONValueBuilder var example: JSONValueRepresentable { if bool { "Hello" } else { "World" } }

    #expect(example.value == (bool ? .string("Hello") : .string("World")))
  }

  @Test func properties() {
    let example = JSONObjectValue {
      JSONPropertyValue(key: "title") { "Industrial Revolution" }
      JSONPropertyValue(key: "tags") {
        "history"
        "science"
        "engineering"
      }
      JSONPropertyValue(key: "version", value: JSONIntegerValue(integer: 1))
      JSONPropertyValue(key: "icon") { JSONNullValue() }
      JSONPropertyValue(key: "hello") {
        JSONObjectValue { JSONPropertyValue(key: "world") { true } }
      }
    }

    #expect(
      example.value
        == JSONValue.object([
          "title": .string("Industrial Revolution"), "tags": ["history", "science", "engineering"],
          "version": 1, "icon": nil, "hello": .object(["world": true]),
        ])
    )
  }
}
