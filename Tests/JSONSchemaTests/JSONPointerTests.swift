import Foundation
import Testing

@testable import JSONSchema

struct JSONPointerTests {
  @Test func emptyInit() {
    let location = JSONPointer()
    #expect(location.path == [])
  }

  @Test(arguments: [
    ("", [JSONPointer.Component]()),
    ("/", [.key("")]),
    ("/foo", [.key("foo")]),
    ("/foo/bar", [.key("foo"), .key("bar")]),
    ("/foo/0", [.key("foo"), .index(0)]),
    ("/0/foo", [.index(0), .key("foo")]),
    ("/01", [.key("01")]),
    ("/+1", [.key("+1")]),
    ("/-0", [.key("-0")]),
    ("/-1", [.key("-1")]),
    ("/a~1b", [.key("a/b")]),
    ("/m~0n", [.key("m~n")]),
  ]) func initFrom(string: String, expected: [JSONPointer.Component]) {
    let location = JSONPointer(from: string)
    #expect(location.path == expected)
  }

  @Test func append() {
    var location = JSONPointer()
    location.append(.key("foo"))
    #expect(location.path == [.key("foo")])
    location.append(.index(0))
    #expect(location.path == [.key("foo"), .index(0)])
  }

  @Test func descriptionEscapesTokens() {
    let pointer = JSONPointer(tokens: ["properties", "foo/bar", "tilde~value"])
    #expect(pointer.description == "#/properties/foo~1bar/tilde~0value")
  }

  @Test func pointerStringHandlesEmptyTokens() {
    #expect(JSONPointer.pointerString(from: []) == "#")
  }

  static let numericTokens = [
    "0", "1", "10", "00", "01", "+0", "+1", "-0", "-1",
    String(Int.max), String(Int.max) + "0",
  ]

  @Test(arguments: numericTokens)
  func numericObjectKeys(token: String) {
    let document: JSONValue = .object([token: .string(token)])
    #expect(document.value(at: JSONPointer(from: "/\(token)")) == .string(token))
    #expect(document.value(at: JSONPointer(tokens: [token])) == .string(token))
  }

  @Test(arguments: numericTokens)
  func numericTokensRoundTrip(token: String) throws {
    let pointer = JSONPointer(tokens: ["a/b", token, "m~n"])
    let expected = "/a~1b/\(token)/m~0n"
    #expect(pointer.jsonPointerString == expected)
    #expect(pointer.description == "#\(expected)")
    #expect(pointer.debugDescription == "#\(expected)")
    #expect(JSONPointer(from: expected) == pointer)
    #expect(JSONPointer(from: "#\(expected)") == pointer)

    let encoded = try JSONEncoder().encode(pointer)
    #expect(try JSONDecoder().decode(String.self, from: encoded) == expected)
    #expect(try JSONDecoder().decode(JSONPointer.self, from: encoded) == pointer)
    #expect(
      pointer.absoluteLocation(relativeTo: URL(string: "https://example.com/schema#old")!)?
        .fragment(percentEncoded: false) == expected
    )
  }

  @Test func nestedNumericAndEscapedTokens() {
    let document: JSONValue = [
      "0": [
        "01": [
          ["0": ["a/b": ["m~n": ["~1": "nested"]]]]
        ]
      ]
    ]
    #expect(document.value(at: "/0/01/0/0/a~1b/m~0n/~01") == "nested")
  }

  @Test(arguments: [0, 1, 10])
  func canonicalArrayIndices(index: Int) {
    let document = JSONValue.array((0 ..< 11).map { .integer($0) })
    #expect(document.value(at: JSONPointer(from: "/\(index)")) == .integer(index))
    #expect(document.value(at: JSONPointer(path: [.key(String(index))])) == .integer(index))
  }

  @Test(arguments: [
    "", "-", "00", "01", "+0", "+1", "-0", "-1", "1.0", "1e0",
    " 0", "0 ", "\n0", "0\n", "\u{0660}", "\u{FF10}",
    "11", String(Int.max), String(Int.max) + "0",
  ])
  func rejectsInvalidArrayIndices(token: String) {
    let document = JSONValue.array((0 ..< 11).map { .integer($0) })
    #expect(document.value(at: JSONPointer(from: "/\(token)")) == nil)
    #expect(document.value(at: JSONPointer(path: [.key(token)])) == nil)
  }

  @Test func missingValuesAndScalarTraversal() {
    #expect(JSONValue.array([]).value(at: "/0") == nil)
    #expect(JSONValue.object(["0": "ok"]).value(at: "/1") == nil)
    #expect(JSONValue.object(["0": "ok"]).value(at: "/0/0") == nil)
    #expect(JSONValue.null.value(at: "/0") == nil)
    #expect(JSONValue.array(["ok"]).value(at: JSONPointer(path: [.index(-1)])) == nil)
  }

  @Test func numericComponentIdentity() {
    let parsed = JSONPointer(from: "/$defs/0")
    let constructed = JSONPointer(path: [.key("$defs"), .key("0")])
    #expect(parsed == constructed)
    #expect(Set([parsed, constructed]).count == 1)
    #expect(parsed.appending(.key("type")).relative(toBase: constructed) == "/type")
    #expect(constructed.appending(.key("type")).relative(toBase: parsed) == "/type")

    #expect(
      Set(Self.numericTokens.map { JSONPointer(tokens: [$0]) }).count == Self.numericTokens.count
    )
    #expect(
      JSONPointer(from: "/$defs/01/type").relative(toBase: parsed) == "/$defs/01/type"
    )
  }

  static let exampleDocument1: JSONValue = [
    "foo": ["bar", "baz"],
    "": 0,
    "a/b": 1,
    "c%d": 2,
    "e^f": 3,
    "g|h": 4,
    #"i\\j"#: 5,
    #"k"l""#: 6,
    " ": 7,
    "m~n": 8,
  ]

  @Test(arguments: [
    (JSONPointer(from: ""), exampleDocument1),
    (JSONPointer(from: "/foo"), JSONValue.array(["bar", "baz"])),
    ("/foo/0", "bar"), ("/", 0),
    ("/a~1b", 1),
    ("/c%d", 2),
    ("/e^f", 3),
  ]) func valueAtPointer(at location: JSONPointer, expected: JSONValue) {
    #expect(Self.exampleDocument1.value(at: location) == expected)
  }

  static let exampleDocument2: JSONValue = [
    "level1": [
      "level2": [
        "level3a": "deepValue1",
        "level3b": [
          "key1": "value1",
          "key2": "value2",
          "nestedArray": [["innerKey": "innerValue1"], ["innerKey": "innerValue2"]],
        ],
        "level3c": ["arrayElement1", "arrayElement2"],
      ]
    ],
    "rootArray": [["arrayLevel2": ["arrayLevel3": "deepValue2"]], "simpleValue"],
    "keyWithEmptyString": ["": "emptyStringValue"],
  ]

  @Test(arguments: [
    // Root level key access
    (
      JSONPointer(from: "/level1"),
      JSONValue.object([
        "level2": [
          "level3a": "deepValue1",
          "level3b": [
            "key1": "value1",
            "key2": "value2",
            "nestedArray": [["innerKey": "innerValue1"], ["innerKey": "innerValue2"]],
          ],
          "level3c": ["arrayElement1", "arrayElement2"],
        ]
      ])
    ),

    // Deeply nested key access
    ("/level1/level2/level3a", "deepValue1"),

    // Accessing a value inside an array
    ("/level1/level2/level3b/nestedArray/0/innerKey", "innerValue1"),
    ("/level1/level2/level3b/nestedArray/1/innerKey", "innerValue2"),

    // Accessing a value inside a simple array
    ("/level1/level2/level3c/0", "arrayElement1"), ("/level1/level2/level3c/1", "arrayElement2"),

    // Accessing a value inside a nested array within another array
    ("/rootArray/0/arrayLevel2/arrayLevel3", "deepValue2"),

    // Accessing a simple value in a root array
    ("/rootArray/1", "simpleValue"),

    // Accessing a key with an empty string
    ("/keyWithEmptyString/", "emptyStringValue"),
  ]) func nestedValueAtPointer(at location: JSONPointer, expected: JSONValue) {
    #expect(Self.exampleDocument2.value(at: location) == expected)
  }
}
