import Testing

@testable import JSONSchema2

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
