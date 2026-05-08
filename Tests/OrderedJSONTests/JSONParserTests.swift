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

  @Test func distinguishesIntegerFromDouble() throws {
    #expect(try JSONValue.parse("0") == .integer(0))
    #expect(try JSONValue.parse("1234567890") == .integer(1_234_567_890))
    #expect(try JSONValue.parse("0.5") == .number(0.5))
    #expect(try JSONValue.parse("1e3") == .number(1000.0))
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

  // MARK: - Depth limit

  @Test func enforcesDepthLimit() {
    // 300 opening brackets — over our 256-deep limit.
    let deep = String(repeating: "[", count: 300)
    #expect(throws: JSONParseError.self) {
      _ = try JSONValue.parse(deep)
    }
  }
}
