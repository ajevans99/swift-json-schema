import Foundation
import OrderedCollections
import OrderedJSON
import Testing

@Suite("JSONValue Codable tests")
struct JSONValueCodableTests {

  // MARK: - Numeric limits and boundaries

  @Test func integerLimits() throws {
    let decoder = JSONDecoder()
    for integer in [Int.min, Int.min + 1, -1, 0, 1, Int.max - 1, Int.max] {
      let json = "\(integer)"
      let value = try decoder.decode(JSONValue.self, from: Data(json.utf8))
      #expect(value == .integer(integer))
    }
  }

  @Test func valuesAroundTwoToTheFiftyThird() throws {
    let decoder = JSONDecoder()
    // 2^53 - 1, 2^53, 2^53 + 1
    let numbers = [
      "9007199254740991",
      "9007199254740992",
      "9007199254740993",
      "-9007199254740991",
      "-9007199254740992",
      "-9007199254740993",
    ]
    for text in numbers {
      let value = try decoder.decode(JSONValue.self, from: Data(text.utf8))
      guard case .numberLiteral(let literal) = value else {
        Issue.record("Expected numberLiteral for \(text)")
        continue
      }
      #expect(literal == (try JSONNumberLiteral(text)))
    }
  }

  @Test func fractionsAndExponents() throws {
    let decoder = JSONDecoder()
    let cases = [
      ("0.125", 0.125),
      ("-12.75", -12.75),
      ("1e2", 100.0),
      ("1e-2", 0.01),
      ("1.5e3", 1500.0),
      ("-2.5e-3", -0.0025),
    ]
    for (text, expectedDouble) in cases {
      let value = try decoder.decode(JSONValue.self, from: Data(text.utf8))
      guard case .numberLiteral(let literal) = value else {
        Issue.record("Expected numberLiteral for \(text)")
        continue
      }
      #expect(try literal.doubleValue() == expectedDouble)
    }
  }

  @Test func decimalPrecisionAndRange() throws {
    let decoder = JSONDecoder()
    // Exact large decimals that must not be rounded by binary Double
    let preserved = [
      "9007199254740993.25",
      "9223372036854775806.5",
      "12345678901234567890.123456789012345678",
      "340282366920938463463374607431768211455",
      "1e-128",
      "1e127",
    ]
    for text in preserved {
      let value = try decoder.decode(JSONValue.self, from: Data(text.utf8))
      guard case .numberLiteral(let literal) = value else {
        Issue.record("Expected numberLiteral for \(text)")
        continue
      }
      #expect(literal == (try JSONNumberLiteral(text)))
    }
  }

  @Test func finiteDoubleExtremes() throws {
    let decoder = JSONDecoder()
    let minPositive = String(Double.leastNonzeroMagnitude)
    let maxFinite = String(Double.greatestFiniteMagnitude)
    for text in [minPositive, maxFinite] {
      let value = try decoder.decode(JSONValue.self, from: Data(text.utf8))
      guard case .numberLiteral(let literal) = value else {
        Issue.record("Expected numberLiteral for \(text)")
        continue
      }
      #expect(try literal.doubleValue().isFinite)
    }
  }

  @Test func signedZeroHandling() throws {
    let decoder = JSONDecoder()
    let value = try decoder.decode(JSONValue.self, from: Data("-0.0".utf8))
    guard case .numberLiteral(let literal) = value else {
      Issue.record("Expected numberLiteral for -0.0")
      return
    }
    #expect(literal == JSONNumberLiteral(0))
  }

  @Test func nonFiniteNumbersRejectedByDefault() {
    let decoder = JSONDecoder()
    for text in ["NaN", "Infinity", "-Infinity"] {
      #expect(throws: (any Error).self) {
        try decoder.decode(JSONValue.self, from: Data(text.utf8))
      }
    }
  }

  // MARK: - Non-JSON decoder interoperability

  @Test func propertyListEncoderDecoderInteroperability() throws {
    let original: JSONValue = .object([
      "string": .string("hello"),
      "integer": .integer(42),
      "boolean": .boolean(true),
      "array": .array([.string("nested"), .integer(100)]),
      "dict": .object(["inner": .boolean(false)]),
    ])

    let data = try PropertyListEncoder().encode(original)
    let decoded = try PropertyListDecoder().decode(JSONValue.self, from: data)

    #expect(decoded == original)
  }

  // MARK: - Nested failure paths

  @Test func nestedFailureReportsCorrectCodingPath() {
    // Malformed JSON inside nested structure
    let malformedNested = """
      {"outer": {"inner": [1, 2, "unclosed string]}}
      """
    let decoder = JSONDecoder()
    #expect(throws: (any Error).self) {
      try decoder.decode(JSONValue.self, from: Data(malformedNested.utf8))
    }
  }

  // MARK: - Semantic differences: JSONDecoder vs JSONValue.parse

  @Test func numericSpellingSemanticsDiffer() throws {
    // JSONValue.parse preserves original textual spelling
    let parsed = try JSONValue.parse("1.000")
    #expect(parsed.numberLiteral?.rawValue == "1.000")

    // JSONDecoder goes through Foundation numeric types, losing trailing zeroes
    let decoded = try JSONDecoder().decode(JSONValue.self, from: Data("1.000".utf8))
    #expect(decoded == .integer(1))
    #expect(decoded.numberLiteral?.rawValue == "1")
  }

  @Test func exponentSpellingSemanticsDiffer() throws {
    let parsed = try JSONValue.parse("1e2")
    #expect(parsed.numberLiteral?.rawValue == "1e2")

    let decoded = try JSONDecoder().decode(JSONValue.self, from: Data("1e2".utf8))
    #expect(decoded == .integer(100))
    #expect(decoded.numberLiteral?.rawValue == "100")
  }

  @Test func duplicateKeySemanticsDiffer() throws {
    let json = #"{"k": 1, "k": 2}"#

    // JSONValue.parse preserves the duplicate key at the trailing position with late-bound value
    let parsed = try JSONValue.parse(json)
    guard case .object(let parsedDict) = parsed else {
      Issue.record("Expected object")
      return
    }
    #expect(parsedDict["k"] == .integer(2))

    // Foundation's JSONDecoder merges keys keeping the first value encountered
    let decoded = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    guard case .object(let decodedDict) = decoded else {
      Issue.record("Expected object")
      return
    }
    #expect(decodedDict["k"] == .integer(1))
  }

  @Test func trailingDataSemanticsDiffer() {
    let json = "[1] [2]"

    // JSONValue.parse rejects trailing content
    #expect(throws: JSONParseError.self) {
      try JSONValue.parse(json)
    }

    // JSONDecoder also rejects trailing content in default configuration
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }
  }

  @Test func objectOrderingSemantics() throws {
    let json = #"{"z": 1, "a": 2, "m": 3}"#

    let parsed = try JSONValue.parse(json)
    guard case .object(let parsedDict) = parsed else {
      Issue.record("Expected object")
      return
    }
    #expect(Array(parsedDict.keys) == ["z", "a", "m"])

    let decoded = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    guard case .object(let decodedDict) = decoded else {
      Issue.record("Expected object")
      return
    }
    // KeyedDecodingContainer.allKeys does not guarantee source order retention across all platforms
    #expect(Set(decodedDict.keys) == Set(["z", "a", "m"]))
  }

  @Test func utf8BOMHandling() throws {
    let bomPrefix = Data([0xEF, 0xBB, 0xBF])
    let jsonBytes = bomPrefix + Data(#"{"key": "value"}"#.utf8)

    // JSONDecoder supports stripping leading UTF-8 BOM
    let decoded = try JSONDecoder().decode(JSONValue.self, from: jsonBytes)
    #expect(decoded == .object(["key": .string("value")]))

    // JSONValue.parse expects clean UTF-8 JSON without leading BOM
    #expect(throws: JSONParseError.self) {
      try JSONValue.parse(jsonBytes)
    }
  }

  @Test func trailingCommaSemantics() throws {
    let trailingCommaObject = #"{"a": 1,}"#
    let trailingCommaArray = "[1, 2,]"

    // JSONValue.parse strictly rejects trailing commas per RFC 8259
    #expect(throws: JSONParseError.self) {
      try JSONValue.parse(trailingCommaObject)
    }
    #expect(throws: JSONParseError.self) {
      try JSONValue.parse(trailingCommaArray)
    }

    // Foundation JSONDecoder may permissively accept trailing commas depending on platform/parser
    let decodedObject = try JSONDecoder()
      .decode(JSONValue.self, from: Data(trailingCommaObject.utf8))
    #expect(decodedObject == .object(["a": .integer(1)]))

    let decodedArray = try JSONDecoder().decode(JSONValue.self, from: Data(trailingCommaArray.utf8))
    #expect(decodedArray == .array([.integer(1), .integer(2)]))
  }

  @Test func depthBoundarySemantics() throws {
    // JSONValue.parse enforces an explicit depth limit of 256
    let depth256 = String(repeating: "[", count: 256) + "1" + String(repeating: "]", count: 256)
    #expect(throws: Never.self) {
      _ = try JSONValue.parse(depth256)
    }

    let depth257 = String(repeating: "[", count: 257) + "1" + String(repeating: "]", count: 257)
    #expect(throws: JSONParseError.self) {
      try JSONValue.parse(depth257)
    }

    // JSONDecoder does not enforce JSONValue's 256 depth boundary
    let decodedDepth257 = try JSONDecoder().decode(JSONValue.self, from: Data(depth257.utf8))
    #expect(decodedDepth257 != .null)
  }
}
