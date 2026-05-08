import Foundation
import OrderedCollections

/// Errors thrown by ``JSONValue/parse(_:)`` when the input is not valid JSON.
public struct JSONParseError: Error, Equatable, Sendable {
  /// A short human-readable description of what went wrong.
  public let message: String
  /// The byte offset (0-based) where the error was detected.
  public let byteOffset: Int
  /// The 1-based line number where the error was detected. Lines are
  /// counted in UTF-8 bytes; both `\n` and `\r\n` advance the counter
  /// (the latter is treated as a single newline so `column` is computed
  /// from the byte after the `\n`).
  public let line: Int
  /// The 1-based column number where the error was detected, measured in
  /// UTF-8 *bytes* — not Unicode scalars or grapheme clusters. This
  /// matches the byte-offset semantics of `byteOffset` and is the cheapest
  /// thing to compute from the parser's position.
  public let column: Int

  public init(message: String, byteOffset: Int, line: Int, column: Int) {
    self.message = message
    self.byteOffset = byteOffset
    self.line = line
    self.column = column
  }
}

extension JSONValue {
  /// Parses a JSON document into a ``JSONValue``, preserving the declared key
  /// order of every object.
  ///
  /// Conforms to RFC 8259. Unlike Foundation's `JSONDecoder`, the order of
  /// keys in each parsed object matches the order they appear in the source
  /// bytes — which makes ``serialized(options:)`` of a parsed value
  /// byte-stable round-trip with the input on a per-key-order basis.
  ///
  /// Implementation notes:
  ///
  /// - Top-level scalars (`null`, booleans, numbers, strings) are accepted
  ///   per the 2017 erratum to RFC 7159 (now required by RFC 8259), matching
  ///   `JSONSerialization.allowFragments` semantics.
  /// - Numbers without a fractional or exponent component are decoded as
  ///   `.integer(Int)` when the value fits in `Int`; otherwise as
  ///   `.number(Double)`.
  /// - Duplicate keys in an object are accepted; the **last** occurrence
  ///   wins on value *and* on position — the late-bound key appears at
  ///   the end of the iteration order, matching what a strict
  ///   "last-write-wins" implementation would emit.
  /// - The byte stream must be valid UTF-8. Other encodings or BOMs are
  ///   rejected.
  ///
  /// - Parameter data: A `Data` containing UTF-8-encoded JSON.
  /// - Returns: The parsed value.
  /// - Throws: ``JSONParseError`` on malformed input.
  public static func parse(_ data: Data) throws -> JSONValue {
    try data.withUnsafeBytes { rawBuffer -> JSONValue in
      let buffer = rawBuffer.bindMemory(to: UInt8.self)
      var parser = JSONParser(bytes: buffer)
      return try parser.parseDocument()
    }
  }

  /// Convenience overload for parsing a JSON `String` directly.
  public static func parse(_ string: String) throws -> JSONValue {
    var copy = string
    return try copy.withUTF8 { utf8 -> JSONValue in
      var parser = JSONParser(bytes: utf8)
      return try parser.parseDocument()
    }
  }
}

// MARK: - Internal parser

/// RFC 8259 streaming parser into ``JSONValue``.
///
/// The parser is intentionally small and self-contained. It walks the input
/// bytes once, building values as it goes. Object keys are appended to an
/// `OrderedDictionary` in source order, so the resulting value reflects the
/// document's declared structure exactly.
///
/// The parser borrows its input as an `UnsafeBufferPointer<UInt8>` so the
/// caller controls the storage lifetime and we avoid copying the whole
/// document into an `Array` — relevant for large payloads.
struct JSONParser {
  let bytes: UnsafeBufferPointer<UInt8>
  var index: Int = 0

  /// Hard limit on the depth of nested objects/arrays. Prevents stack
  /// overflow on adversarially deep input (e.g. JSONTestSuite's
  /// `n_structure_100000_opening_arrays.json`). 256 comfortably accepts
  /// any reasonable real-world JSON; legitimate use cases rarely exceed
  /// 100 levels. The value is conservative because debug-build stack
  /// frames are large enough that allowing deeper recursion risks
  /// overflowing the macOS thread default (1MB) before the explicit
  /// check fires.
  static let maxDepth: Int = 256
  var depth: Int = 0

  // MARK: ASCII / control byte constants

  private static let space: UInt8 = 0x20
  private static let tab: UInt8 = 0x09
  private static let lf: UInt8 = 0x0A
  private static let cr: UInt8 = 0x0D
  private static let quote: UInt8 = 0x22  // "
  private static let backslash: UInt8 = 0x5C  // \
  private static let openBrace: UInt8 = 0x7B  // {
  private static let closeBrace: UInt8 = 0x7D  // }
  private static let openBracket: UInt8 = 0x5B  // [
  private static let closeBracket: UInt8 = 0x5D  // ]
  private static let comma: UInt8 = 0x2C  // ,
  private static let colon: UInt8 = 0x3A  // :
  private static let minus: UInt8 = 0x2D  // -
  private static let plus: UInt8 = 0x2B  // +
  private static let period: UInt8 = 0x2E  // .
  private static let zero: UInt8 = 0x30  // 0
  private static let nine: UInt8 = 0x39  // 9
  private static let lowerA: UInt8 = 0x61
  private static let lowerB: UInt8 = 0x62
  private static let lowerE: UInt8 = 0x65
  private static let lowerF: UInt8 = 0x66
  private static let lowerN: UInt8 = 0x6E
  private static let lowerR: UInt8 = 0x72
  private static let lowerT: UInt8 = 0x74
  private static let lowerU: UInt8 = 0x75
  private static let upperA: UInt8 = 0x41
  private static let upperE: UInt8 = 0x45
  private static let upperF: UInt8 = 0x46

  // MARK: - Top-level

  mutating func parseDocument() throws -> JSONValue {
    skipWhitespace()
    guard index < bytes.count else {
      throw error("Unexpected end of input")
    }
    let value = try parseValue()
    skipWhitespace()
    if index < bytes.count {
      throw error("Unexpected trailing data")
    }
    return value
  }

  // MARK: - Whitespace / position

  private mutating func skipWhitespace() {
    while index < bytes.count {
      let b = bytes[index]
      guard b == Self.space || b == Self.tab || b == Self.lf || b == Self.cr else {
        return
      }
      index += 1
    }
  }

  private func peek() -> UInt8? {
    index < bytes.count ? bytes[index] : nil
  }

  private mutating func expect(_ byte: UInt8) throws {
    guard index < bytes.count else {
      throw error("Unexpected end of input")
    }
    guard bytes[index] == byte else {
      throw error(
        "Expected '\(Character(UnicodeScalar(byte)))' but found '\(printable(bytes[index]))'"
      )
    }
    index += 1
  }

  // MARK: - Dispatch

  mutating func parseValue() throws -> JSONValue {
    skipWhitespace()
    guard let b = peek() else {
      throw error("Unexpected end of input while reading value")
    }
    switch b {
    case Self.openBrace: return try parseObject()
    case Self.openBracket: return try parseArray()
    case Self.quote: return .string(try parseString())
    case Self.lowerT, Self.lowerF: return try parseBool()
    case Self.lowerN: return try parseNull()
    case Self.minus, Self.zero ... Self.nine: return try parseNumber()
    default:
      throw error("Unexpected character '\(printable(b))'")
    }
  }

  // MARK: - Structure

  mutating func parseObject() throws -> JSONValue {
    try expect(Self.openBrace)
    depth += 1
    defer { depth -= 1 }
    if depth > Self.maxDepth {
      throw error("Maximum nesting depth (\(Self.maxDepth)) exceeded")
    }
    var dict = OrderedDictionary<String, JSONValue>()
    skipWhitespace()
    if peek() == Self.closeBrace {
      index += 1
      return .object(dict)
    }
    while true {
      skipWhitespace()
      guard peek() == Self.quote else {
        throw error("Expected string key in object")
      }
      let key = try parseString()
      skipWhitespace()
      try expect(Self.colon)
      let value = try parseValue()
      // For duplicate keys: remove the previous entry first, then insert.
      // OrderedDictionary's subscript-set updates the existing slot in
      // place, which would leave the late-bound key at its original
      // position. The documented behavior is "last occurrence wins on
      // value AND position", so re-insert.
      if dict[key] != nil {
        dict.removeValue(forKey: key)
      }
      dict[key] = value
      skipWhitespace()
      switch peek() {
      case Self.comma:
        index += 1
      case Self.closeBrace:
        index += 1
        return .object(dict)
      case nil:
        throw error("Unexpected end of input inside object")
      default:
        throw error("Expected ',' or '}' in object")
      }
    }
  }

  mutating func parseArray() throws -> JSONValue {
    try expect(Self.openBracket)
    depth += 1
    defer { depth -= 1 }
    if depth > Self.maxDepth {
      throw error("Maximum nesting depth (\(Self.maxDepth)) exceeded")
    }
    var array: [JSONValue] = []
    skipWhitespace()
    if peek() == Self.closeBracket {
      index += 1
      return .array(array)
    }
    while true {
      let value = try parseValue()
      array.append(value)
      skipWhitespace()
      switch peek() {
      case Self.comma:
        index += 1
      case Self.closeBracket:
        index += 1
        return .array(array)
      case nil:
        throw error("Unexpected end of input inside array")
      default:
        throw error("Expected ',' or ']' in array")
      }
    }
  }

  // MARK: - Literals

  mutating func parseNull() throws -> JSONValue {
    try matchLiteral([0x6E, 0x75, 0x6C, 0x6C], name: "null")
    return .null
  }

  mutating func parseBool() throws -> JSONValue {
    guard peek() == Self.lowerT else {
      try matchLiteral([0x66, 0x61, 0x6C, 0x73, 0x65], name: "false")
      return .boolean(false)
    }
    try matchLiteral([0x74, 0x72, 0x75, 0x65], name: "true")
    return .boolean(true)
  }

  private mutating func matchLiteral(_ literal: [UInt8], name: String) throws {
    guard index + literal.count <= bytes.count else {
      throw error("Unexpected end of input while reading literal '\(name)'")
    }
    for byte in literal {
      if bytes[index] != byte {
        throw error("Invalid literal — expected '\(name)'")
      }
      index += 1
    }
  }

  // MARK: - Strings

  /// Parses a JSON string starting at the leading quote. Returns the decoded
  /// Swift string with all escape sequences resolved.
  mutating func parseString() throws -> String {
    try expect(Self.quote)
    var scalars: [Unicode.Scalar] = []
    while index < bytes.count {
      let b = bytes[index]
      switch b {
      case Self.quote:
        index += 1
        return String(String.UnicodeScalarView(scalars))
      case Self.backslash:
        index += 1
        try parseEscape(into: &scalars)
      case 0x00 ... 0x1F:
        throw error("Unescaped control character (0x\(String(b, radix: 16))) in string")
      default:
        // Decode a UTF-8 scalar starting at bytes[index].
        let scalar = try decodeUTF8Scalar()
        scalars.append(scalar)
      }
    }
    throw error("Unterminated string")
  }

  /// Reads bytes for a single UTF-8 scalar starting at `bytes[index]`,
  /// advances `index`, and returns the decoded scalar. Rejects invalid UTF-8.
  private mutating func decodeUTF8Scalar() throws -> Unicode.Scalar {
    let lead = bytes[index]
    let length: Int
    var value: UInt32
    if lead < 0x80 {
      length = 1
      value = UInt32(lead)
    } else if lead < 0xC2 {
      throw error("Invalid UTF-8 leading byte")
    } else if lead < 0xE0 {
      length = 2
      value = UInt32(lead & 0x1F)
    } else if lead < 0xF0 {
      length = 3
      value = UInt32(lead & 0x0F)
    } else if lead < 0xF5 {
      length = 4
      value = UInt32(lead & 0x07)
    } else {
      throw error("Invalid UTF-8 leading byte")
    }
    guard index + length <= bytes.count else {
      throw error("Truncated UTF-8 sequence")
    }
    for i in 1 ..< length {
      let b = bytes[index + i]
      if b & 0xC0 != 0x80 {
        throw error("Invalid UTF-8 continuation byte")
      }
      value = (value << 6) | UInt32(b & 0x3F)
    }
    index += length
    guard let scalar = Unicode.Scalar(value) else {
      throw error("Invalid UTF-8 scalar value U+\(String(value, radix: 16, uppercase: true))")
    }
    return scalar
  }

  private mutating func parseEscape(into scalars: inout [Unicode.Scalar]) throws {
    guard index < bytes.count else {
      throw error("Unexpected end of input after backslash")
    }
    let b = bytes[index]
    index += 1
    switch b {
    case Self.quote: scalars.append(Unicode.Scalar(0x22))
    case Self.backslash: scalars.append(Unicode.Scalar(0x5C))
    // Forward slash (`/`) — JSON spec lets implementations escape it.
    case 0x2F: scalars.append(Unicode.Scalar(0x2F))
    case Self.lowerB: scalars.append(Unicode.Scalar(0x08))
    case Self.lowerF: scalars.append(Unicode.Scalar(0x0C))
    case Self.lowerN: scalars.append(Unicode.Scalar(0x0A))
    case Self.lowerR: scalars.append(Unicode.Scalar(0x0D))
    case Self.lowerT: scalars.append(Unicode.Scalar(0x09))
    case Self.lowerU:
      let scalar = try parseUnicodeEscape()
      scalars.append(scalar)
    default:
      throw error("Invalid escape character '\\\\(printable(b))'")
    }
  }

  /// Reads `XXXX` after `\u`, handling UTF-16 surrogate pairs.
  private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
    let high = try readHex4()
    if (0xD800 ... 0xDBFF).contains(high) {
      // High surrogate — must be followed by `\uXXXX` low surrogate.
      guard index + 1 < bytes.count, bytes[index] == Self.backslash, bytes[index + 1] == Self.lowerU
      else {
        throw error("Unpaired UTF-16 high surrogate")
      }
      index += 2
      let low = try readHex4()
      guard (0xDC00 ... 0xDFFF).contains(low) else {
        throw error("Invalid UTF-16 low surrogate")
      }
      let codepoint = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
      guard let scalar = Unicode.Scalar(codepoint) else {
        throw error("Invalid surrogate-pair code point")
      }
      return scalar
    }
    if (0xDC00 ... 0xDFFF).contains(high) {
      throw error("Unpaired UTF-16 low surrogate")
    }
    guard let scalar = Unicode.Scalar(high) else {
      throw error("Invalid \\u escape value")
    }
    return scalar
  }

  private mutating func readHex4() throws -> UInt32 {
    guard index + 4 <= bytes.count else {
      throw error("Truncated \\u escape")
    }
    var value: UInt32 = 0
    for _ in 0 ..< 4 {
      let b = bytes[index]
      let digit: UInt32
      switch b {
      case Self.zero ... Self.nine: digit = UInt32(b - Self.zero)
      case Self.lowerA ... Self.lowerF: digit = UInt32(b - Self.lowerA + 10)
      case Self.upperA ... Self.upperF: digit = UInt32(b - Self.upperA + 10)
      default: throw error("Invalid hex digit '\(printable(b))' in \\u escape")
      }
      value = (value << 4) | digit
      index += 1
    }
    return value
  }

  // MARK: - Numbers

  mutating func parseNumber() throws -> JSONValue {
    let start = index
    var isInteger = true

    if peek() == Self.minus {
      index += 1
    }

    // Integer part.
    guard let firstDigit = peek(), firstDigit >= Self.zero, firstDigit <= Self.nine else {
      throw error("Expected digit in number")
    }
    if firstDigit == Self.zero {
      index += 1
      // RFC 8259: leading zeros are not allowed (e.g. "01" is invalid).
      if let next = peek(), next >= Self.zero, next <= Self.nine {
        throw error("Leading zeros are not allowed in numbers")
      }
    } else {
      while let b = peek(), b >= Self.zero, b <= Self.nine { index += 1 }
    }

    // Fraction part.
    if peek() == Self.period {
      isInteger = false
      index += 1
      guard let b = peek(), b >= Self.zero, b <= Self.nine else {
        throw error("Expected digit after decimal point")
      }
      while let b = peek(), b >= Self.zero, b <= Self.nine { index += 1 }
    }

    // Exponent part.
    if let b = peek(), b == Self.lowerE || b == Self.upperE {
      isInteger = false
      index += 1
      if let s = peek(), s == Self.plus || s == Self.minus { index += 1 }
      guard let d = peek(), d >= Self.zero, d <= Self.nine else {
        throw error("Expected digit in exponent")
      }
      while let b = peek(), b >= Self.zero, b <= Self.nine { index += 1 }
    }

    let length = index - start
    let str = String(
      unsafeUninitializedCapacity: length,
      initializingUTF8With: { buffer in
        for i in 0 ..< length { buffer[i] = bytes[start + i] }
        return length
      }
    )
    if isInteger, let int = Int(str) {
      return .integer(int)
    }
    guard let double = Double(str) else {
      throw error("Invalid number '\(str)'")
    }
    return .number(double)
  }

  // MARK: - Errors

  private func error(_ message: String) -> JSONParseError {
    let (line, column) = positionForOffset(index)
    return JSONParseError(message: message, byteOffset: index, line: line, column: column)
  }

  /// Computes the 1-based line and 1-based byte-column for a given byte
  /// offset. Both `\n` and `\r\n` advance the line counter and reset the
  /// column. A bare `\r` (Mac-classic) is treated as a newline too.
  private func positionForOffset(_ offset: Int) -> (line: Int, column: Int) {
    var line = 1
    var column = 1
    let limit = min(offset, bytes.count)
    var i = 0
    while i < limit {
      let b = bytes[i]
      if b == Self.cr {
        line += 1
        column = 1
        // Treat \r\n as a single newline.
        if i + 1 < limit, bytes[i + 1] == Self.lf {
          i += 1
        }
      } else if b == Self.lf {
        line += 1
        column = 1
      } else {
        column += 1
      }
      i += 1
    }
    return (line, column)
  }

  private func printable(_ b: UInt8) -> String {
    if b >= 0x20, b < 0x7F {
      return String(UnicodeScalar(b))
    }
    return "\\x\(String(b, radix: 16, uppercase: false))"
  }
}
