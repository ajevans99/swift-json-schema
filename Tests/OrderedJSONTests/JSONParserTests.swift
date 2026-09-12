import Foundation
import OrderedCollections
import OrderedJSON
import Testing

@Suite("JSON parser unit tests")
struct JSONParserTests {

  // MARK: - Top-level scalars

  @Test func parsesTopLevelScalars() throws {
    #expect(try JSONValue.parse("null") == .null)
    #expect(try JSONValue.parse("true") == .boolean(true))
    #expect(try JSONValue.parse("false") == .boolean(false))
    #expect(try JSONValue.parse("42") == .integer(42))
    #expect(try JSONValue.parse("-3.14") == .number(-3.14))
    #expect(try JSONValue.parse("\"hello\"") == .string("hello"))
  }

  // MARK: - Object key ordering

  @Test func preservesObjectKeyOrder() throws {
    let value = try JSONValue.parse(#"{"z":1,"a":2,"m":3}"#)
    guard case .object(let dict) = value else {
      Issue.record("Expected object")
      return
    }
    #expect(Array(dict.keys) == ["z", "a", "m"])
  }

  // MARK: - Duplicate key handling

  /// When the same key appears twice, the late-bound value wins AND the
  /// late-bound key occupies the *last* position in iteration order.
  /// This matches the documented "last occurrence wins on value and
  /// position" contract.
  @Test func duplicateKeyEndsAtTrailingPosition() throws {
    let value = try JSONValue.parse(#"{"a":1,"b":2,"c":3,"a":99}"#)
    guard case .object(let dict) = value else {
      Issue.record("Expected object")
      return
    }
    #expect(Array(dict.keys) == ["b", "c", "a"])
    #expect(dict["a"] == .integer(99))
  }

  // MARK: - Strings & escapes

  @Test func parsesStandardEscapes() throws {
    let value = try JSONValue.parse(#""line1\nline2\ttab\\backslash\"quote""#)
    #expect(value == .string("line1\nline2\ttab\\backslash\"quote"))
  }

  @Test func parsesUnicodeEscapeAndSurrogatePair() throws {
    // 𝄞 (U+1D11E, MUSICAL SYMBOL G CLEF) — encoded as a UTF-16 surrogate pair.
    let value = try JSONValue.parse(#""\uD834\uDD1E""#)
    #expect(value == .string("𝄞"))
  }

  // MARK: - Numbers

  @Test func preservesNumberValuesAndSpelling() throws {
    #expect(try JSONValue.parse("0") == .integer(0))
    #expect(try JSONValue.parse("1234567890") == .integer(1_234_567_890))
    #expect(try JSONValue.parse("0.5") == .number(0.5))
    #expect(try JSONValue.parse("1e3") == .number(1000.0))
    #expect(try JSONValue.parse("1e3").numberLiteral?.rawValue == "1e3")
  }

  // MARK: - Error reporting

  @Test func errorIncludesByteOffsetAndLine() {
    let bad = """
      {
        "a": 1,
        "b" 2
      }
      """
    do {
      _ = try JSONValue.parse(bad)
      Issue.record("Expected parse to fail")
    } catch let err as JSONParseError {
      #expect(err.line == 3, "Expected error on line 3, got \(err.line)")
      #expect(err.column > 0)
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }

  @Test func crLfAdvancesLineCounter() {
    // Same shape, but with CRLF line endings.
    let bad = "{\r\n  \"a\": 1,\r\n  \"b\" 2\r\n}"
    do {
      _ = try JSONValue.parse(bad)
      Issue.record("Expected parse to fail")
    } catch let err as JSONParseError {
      #expect(err.line == 3)
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }
  }

  @Test(arguments: [
    ("", "Unexpected end of input", 0),
    ("[", "Unexpected end of input while reading value", 1),
    ("{", "Expected string key in object", 1),
    ("[1", "Unexpected end of input inside array", 2),
    (#"{"a":1"#, "Unexpected end of input inside object", 6),
    ("[1,", "Unexpected end of input while reading value", 3),
    (#"{"a":1,"#, "Expected string key in object", 7),
    (#"{"a""#, "Unexpected end of input", 4),
    (#"{"a" 1}"#, "Expected ':' but found '1'", 5),
    (#"{"a":"#, "Unexpected end of input while reading value", 5),
    ("[1,]", "Unexpected character ']'", 3),
    (#"{"a":1,}"#, "Expected string key in object", 7),
    ("[,1]", "Unexpected character ','", 1),
    ("{,}", "Expected string key in object", 1),
    ("[1 2]", "Expected ',' or ']' in array", 3),
    (#"{"a":1 "b":2}"#, "Expected ',' or '}' in object", 7),
    ("[1}", "Expected ',' or ']' in array", 2),
    (#"{"a":1]"#, "Expected ',' or '}' in object", 6),
    ("[{}", "Unexpected end of input inside array", 3),
    (#"{"a":[]"#, "Unexpected end of input inside object", 7),
    ("[{} true]", "Expected ',' or ']' in array", 4),
    (#"{"a":[] "b":2}"#, "Expected ',' or '}' in object", 8),
    ("[{} , ]", "Unexpected character ']'", 6),
    (#"[{"a": }]"#, "Unexpected character '}'", 7),
    ("[]{}", "Unexpected trailing data", 2),
    ("[{]", "Expected string key in object", 2),
    (#"{"a":[}"#, "Unexpected character '}'", 6),
    (#"[{"a":[1,]}]"#, "Unexpected character ']'", 9),
  ])
  func structuralErrorsRetainExactOffsets(json: String, message: String, offset: Int) {
    let expected = JSONParseError(
      message: message,
      byteOffset: offset,
      line: 1,
      column: offset + 1
    )
    #expect(throws: expected) {
      _ = try JSONValue.parse(json)
    }
    #expect(throws: expected) {
      _ = try JSONValue.parse(Data(json.utf8))
    }
  }

  @Test func resumesParentsAfterEmptyAndNonemptyChildren() throws {
    let json = #"{"a":[{},[],{"b":[1,2]},3],"z":{},"tail":[{"last":[]},4]}"#
    let expected: JSONValue = .object([
      "a": .array([
        .object([:]), .array([]), .object(["b": .array([.integer(1), .integer(2)])]), .integer(3),
      ]),
      "z": .object([:]),
      "tail": .array([.object(["last": .array([])]), .integer(4)]),
    ])
    for value in [try JSONValue.parse(json), try JSONValue.parse(Data(json.utf8))] {
      #expect(value == expected)
      guard case .object(let object) = value else {
        Issue.record("Expected object")
        return
      }
      #expect(Array(object.keys) == ["a", "z", "tail"])
    }
  }

  // MARK: - Depth limit

  @Test func arrayDepthBoundaryFromString() throws {
    let allowed =
      String(repeating: "[", count: 256) + "42"
      + String(repeating: "]", count: 256)
    let parsed = try JSONValue.parse(allowed)
    expectNestedValue(parsed, isObjectAtDepth: { _ in false })
    let parsedData = try JSONValue.parse(Data(allowed.utf8))
    expectNestedValue(parsedData, isObjectAtDepth: { _ in false })

    let rejected = "[" + allowed + "]"
    let expectedError = JSONParseError(
      message: "Maximum nesting depth (256) exceeded",
      byteOffset: 257,
      line: 1,
      column: 258
    )
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(rejected)
    }
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(Data(rejected.utf8))
    }
  }

  @Test func objectDepthBoundaryFromData() throws {
    let allowed =
      String(repeating: #"{"v":"#, count: 256) + "42"
      + String(repeating: "}", count: 256)
    let parsed = try JSONValue.parse(Data(allowed.utf8))
    expectNestedValue(parsed, isObjectAtDepth: { _ in true })
    let parsedString = try JSONValue.parse(allowed)
    expectNestedValue(parsedString, isObjectAtDepth: { _ in true })

    let rejected = #"{"v":"# + allowed + "}"
    let expectedError = JSONParseError(
      message: "Maximum nesting depth (256) exceeded",
      byteOffset: 256 * 5 + 1,
      line: 1,
      column: 256 * 5 + 2
    )
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(Data(rejected.utf8))
    }
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(rejected)
    }
  }

  @Test func mixedContainerDepthBoundaryFromStringAndData() throws {
    let prefix = String(repeating: #"[{"v":"#, count: 128)
    let suffix = String(repeating: "}]", count: 128)
    let allowed = prefix + "42" + suffix
    let parsedString = try JSONValue.parse(allowed)
    expectNestedValue(parsedString, isObjectAtDepth: { $0.isMultiple(of: 2) == false })
    let parsedData = try JSONValue.parse(Data(allowed.utf8))
    expectNestedValue(parsedData, isObjectAtDepth: { $0.isMultiple(of: 2) == false })

    // Each pair contributes two levels; the innermost array is level 257.
    let rejected = prefix + "[42]" + suffix
    let expectedError = JSONParseError(
      message: "Maximum nesting depth (256) exceeded",
      byteOffset: 128 * 6 + 1,
      line: 1,
      column: 128 * 6 + 2
    )
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(rejected)
    }
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(Data(rejected.utf8))
    }
  }

  @Test(arguments: ["{}", "[]"])
  func emptyContainersCountTowardDepthLimit(leaf: String) throws {
    let prefix = String(repeating: #"{"v":"#, count: 255)
    let suffix = String(repeating: "}", count: 255)
    let allowed = prefix + leaf + suffix
    for value in [try JSONValue.parse(allowed), try JSONValue.parse(Data(allowed.utf8))] {
      var current = value
      for _ in 0 ..< 255 {
        guard case .object(let object) = current, let child = object["v"] else {
          Issue.record("Expected object child")
          return
        }
        #expect(Array(object.keys) == ["v"])
        current = child
      }
      #expect(current == (leaf == "{}" ? .object([:]) : .array([])))
    }

    let rejected = #"{"v":"# + allowed + "}"
    let expectedError = JSONParseError(
      message: "Maximum nesting depth (256) exceeded",
      byteOffset: 1281,
      line: 1,
      column: 1282
    )
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(rejected)
    }
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(Data(rejected.utf8))
    }
  }

  @Test func depthLimitIsRestoredForSiblingsAndDuplicateKeys() throws {
    let child =
      String(repeating: #"{"v":"#, count: 255) + "42"
      + String(repeating: "}", count: 255)
    let json = #"{"first":"# + child + #","middle":[],"first":"# + child + #","last":{}}"#
    for value in [try JSONValue.parse(json), try JSONValue.parse(Data(json.utf8))] {
      guard case .object(let object) = value, let nested = object["first"] else {
        Issue.record("Expected nested object")
        return
      }
      #expect(Array(object.keys) == ["middle", "first", "last"])
      expectNestedValue(nested, depth: 255, isObjectAtDepth: { _ in true })
    }
  }

  @Test func depthErrorRetainsUTF8AndCRLFPosition() {
    let prefix = "{\r\n\"é\":\r\n"
    let rejected =
      prefix + String(repeating: "[", count: 256) + "42"
      + String(repeating: "]", count: 256) + "}"
    let expectedError = JSONParseError(
      message: "Maximum nesting depth (256) exceeded",
      byteOffset: prefix.utf8.count + 256,
      line: 3,
      column: 257
    )
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(rejected)
    }
    #expect(throws: expectedError) {
      _ = try JSONValue.parse(Data(rejected.utf8))
    }
  }

  private func expectNestedValue(
    _ value: JSONValue,
    depth: Int = 256,
    isObjectAtDepth: (Int) -> Bool
  ) {
    // Inspect one level at a time without recursively comparing or formatting
    // the entire depth-256 value in a testing expression.
    var current = value
    for level in 0 ..< depth {
      if isObjectAtDepth(level) {
        guard case .object(let object) = current else {
          Issue.record("Expected object at depth \(level + 1)")
          return
        }
        #expect(Array(object.keys) == ["v"])
        guard let child = object["v"] else {
          Issue.record("Missing object child at depth \(level + 1)")
          return
        }
        current = child
      } else {
        guard case .array(let array) = current else {
          Issue.record("Expected array at depth \(level + 1)")
          return
        }
        #expect(array.count == 1)
        guard let child = array.first else {
          Issue.record("Missing array child at depth \(level + 1)")
          return
        }
        current = child
      }
    }
    guard let leaf = current.integer else {
      Issue.record("Expected integer leaf after \(depth) containers")
      return
    }
    #expect(leaf == 42)
  }

  @Test(arguments: [false, true])
  func enforcesDepthLimitForMixedContainers(dataInput: Bool) {
    let deep = String(repeating: #"[{"":"#, count: 300)
    #expect(throws: JSONParseError.self) {
      if dataInput {
        _ = try JSONValue.parse(Data(deep.utf8))
      } else {
        _ = try JSONValue.parse(deep)
      }
    }
  }
}
