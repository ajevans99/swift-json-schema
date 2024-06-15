@testable import JSONResultBuilders

import JSONSchema
import Testing

struct JSONValueBuilderTests {
  @Test
  func variadicParameter() {
    @JSONBuilder var object: JSONRepresentable {
      JSONStringElement(string: "Hello")
    }

    // Single expression should not build to array
    #expect(object.value == .string("Hello"))

    @JSONBuilder var array: JSONRepresentable {
      JSONStringElement(string: "Hello")
      JSONStringElement(string: "World")
    }

    // Two or more expressions should build to array
    #expect(array.value == .array([.string("Hello"), .string("World")]))
  }

  @Test
  func typeHints() {
    @JSONBuilder var example: JSONRepresentable {
      "Hello"
      1
      false
      2.0
      nil
      [JSONStringElement(string: "a"), JSONStringElement(string: "b")]
      ["Hello": JSONNullElement()]
      // ["a", "b"] // Causes compiler error
      // ["a": 1] // Causes compiler error
    }

    #expect(
      example.value
      ==
      [
        .string("Hello"),
        .integer(1),
        .boolean(false),
        .number(2.0),
        .null,
        .array([.string("a"), .string("b")]),
        .object(["Hello": .null])
      ]
    )
  }

  @Test
  func composition() {
    @JSONBuilder var hello: JSONRepresentable {
      "Hello"
    }

    @JSONBuilder var world: JSONRepresentable {
      "World"
    }

    @JSONBuilder var together: JSONRepresentable {
      hello
      world
    }

    #expect(together.value == .array([.string("Hello"), .string("World")]))
  }

  @Test
  func array() {
    let strings = [
      "Steam Engine",
      "Factory System",
      "Mass Production",
      "Urbanization",
      "Textile Industry",
      "Railroads",
      "Mechanization",
      "Labor Unions",
      "Child Labor",
      "Industrialization"
    ]
    @JSONBuilder var example: JSONRepresentable {
      for string in strings {
        string
      }
    }

    #expect(example.value == .array(strings.map { .string($0) }))
  }

  @Test(arguments: [true, false])
  func optional(_ bool: Bool) {
    @JSONBuilder var example: JSONRepresentable {
      if bool {
        "Hello"
      }
    }

    #expect(example.value == (bool ? .string("Hello") : .null))
  }

  @Test(arguments: [true, false])
  func either(_ bool: Bool) {
    @JSONBuilder var example: JSONRepresentable {
      if bool {
        "Hello"
      } else {
        "World"
      }
    }

    #expect(example.value == (bool ? .string("Hello") : .string("World")))
  }

  @Test
  func properties() {
    let example = JSONObjectElement {
      Property(key: "title") {
        "Industrial Revolution"
      }
      Property(key: "tags") {
        "history"
        "science"
        "engineering"
      }
      Property(key: "version", value: JSONIntegerElement(integer: 1))
      Property(key: "icon") { nil }
      Property(key: "hello") {
        JSONObjectElement {
          Property(key: "world") {
            true
          }
        }
      }
    }

    #expect(
      example.value
      ==
      JSONValue.object([
        "title": .string("Industrial Revolution"),
        "tags": ["history", "science", "engineering"],
        "version": 1,
        "icon": nil,
        "hello": .object(["world": true])
      ])
    )
  }
}
