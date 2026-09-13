import Foundation
import OrderedJSON
import Testing

@Suite("Exact JSON number literals")
struct JSONNumberLiteralTests {
  typealias ConversionError = JSONNumberLiteral.ConversionError

  @Test(arguments: [
    "0", "-0", "1", "-1", "12345678901234567890123456789012345678901234567890",
    "0.0", "-0.0", "0.125", "-12.75", "1e2", "1E+2", "1e-2", "1e0002",
    "-12.3400E-00005", "1e999999999999999999999999", "1e-999999999999999999999999",
  ])
  func validGrammarPreservesLexeme(_ text: String) throws {
    let value = try JSONNumberLiteral(text)
    #expect(value.rawValue == text)
    #expect(value.description == text)
  }

  @Test(arguments: [
    "", "-", "+1", "00", "01", "-01", ".1", "-.1", "1.", "1.e2", "1e", "1E",
    "1e+", "1e-", "1e+-2", "1e--2", "--1", "1_000", "1,000", "0x10", "NaN",
    "nan", "Infinity", "-Infinity", "inf", " 1", "1 ", "\t1", "1\n", "1 2",
    "١", "１", "−1", "1\u{0}", "1/2", "1e2.0", "1e2e3",
  ])
  func invalidGrammar(_ text: String) {
    #expect(throws: ConversionError.invalidLiteral(text)) { try JSONNumberLiteral(text) }
  }

  @Test(arguments: [
    ("0", true, true), ("-0.000e999999999999999999999999", true, true),
    ("0e-999999999999999999999999", true, true), ("-12", true, false),
    ("1e2", true, false), ("1.00", true, false), ("100e-2", true, false),
    ("1e-2", false, false), ("1.001", false, false), ("1e1000", true, false),
    ("1e-999999999999999999999999", false, false),
  ])
  func mathematicalProperties(_ text: String, _ integer: Bool, _ zero: Bool) throws {
    let value = try JSONNumberLiteral(text)
    #expect(value.isInteger == integer)
    #expect(value.isZero == zero)
  }

  @Test func integerConversion() throws {
    for integer in [Int.min, Int.min + 1, -100, -1, 0, 1, 100, Int.max - 1, Int.max] {
      let value = JSONNumberLiteral(integer)
      #expect(value.rawValue == String(integer))
      #expect(try value.integerValue() == integer)
      #expect(try JSONNumberLiteral(String(integer) + ".0").integerValue() == integer)
    }
    #expect(try JSONNumberLiteral("1e2").integerValue() == 100)
    #expect(try JSONNumberLiteral("-0e999999999999999999999999").integerValue() == 0)
    #expect(throws: ConversionError.inexactConversion) {
      try JSONNumberLiteral("1.5").integerValue()
    }
    for text in ["9223372036854775808", "-9223372036854775809", "1e1000"] {
      #expect(throws: ConversionError.outOfRange) { try JSONNumberLiteral(text).integerValue() }
    }
  }

  @Test func signedZeroPreservation() throws {
    let negativeZero = try JSONNumberLiteral("-0")
    #expect(negativeZero.rawValue == "-0")
    #expect(negativeZero == JSONNumberLiteral(0))
    #expect(try negativeZero.doubleValue().sign == .minus)
    #expect(try JSONNumberLiteral(-Double.zero).rawValue == "-0.0")
    #expect(try JSONNumberLiteral("-0e-999999999999999999999999").doubleValue().sign == .minus)
  }

  @Test func doubleConversion() throws {
    for number in [0.1, 9.27, -123.5, Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude]
    {
      #expect(try JSONNumberLiteral(number).doubleValue() == number)
    }
    #expect(try JSONNumberLiteral("9007199254740991").doubleValue() == 9_007_199_254_740_991)
    #expect(try JSONNumberLiteral("9007199254740992").doubleValue() == 9_007_199_254_740_992)
    #expect(try JSONNumberLiteral("9007199254740993").doubleValue() == 9_007_199_254_740_992)
    #expect(try JSONNumberLiteral("9007199254740993") != JSONNumberLiteral("9007199254740992"))
    #expect(try JSONNumberLiteral("5e-324").doubleValue() == Double.leastNonzeroMagnitude)
    for text in [
      "1e-400", "-1e-400", "1e1000", "-1e1000",
      "1e999999999999999999999999", "1e-999999999999999999999999",
    ] {
      #expect(throws: ConversionError.outOfRange) { try JSONNumberLiteral(text).doubleValue() }
    }
    for value in [Double.nan, .infinity, -.infinity] {
      #expect(throws: ConversionError.nonFinite) { try JSONNumberLiteral(value) }
    }
  }

  @Test func doubleConstructionPreservesExactIntegers() throws {
    for double in [
      Double(Int.min), Double(Int.min).nextUp, -100.0, 0.0, 100.0,
      9_007_199_254_740_991.0, 9_007_199_254_740_992.0, Double(Int.max).nextDown,
    ] {
      let integer = try #require(Int(exactly: double))
      let value = try JSONNumberLiteral(double)
      #expect(value.rawValue == String(integer) + ".0")
      #expect(try value.integerValue() == integer)
      #expect(value == JSONNumberLiteral(integer))
      #expect(try value.doubleValue() == double)
    }
    #expect(try JSONNumberLiteral(Double(Int.min)).rawValue == String(Int.min) + ".0")
    #expect(try JSONNumberLiteral(0.0).rawValue == "0.0")
    #expect(try JSONNumberLiteral(-0.0).rawValue == "-0.0")
    #expect(try JSONNumberLiteral(Double(Int.max)).rawValue == String(Double(Int.max)))
    #expect(throws: ConversionError.outOfRange) {
      try JSONNumberLiteral(Double(Int.max)).integerValue()
    }
  }

  @Test func exactDecimalConversion() throws {
    let locale = Locale(identifier: "en_US_POSIX")
    let expected = try #require(Decimal(string: "9.27", locale: locale))
    #expect(try JSONNumberLiteral("9.27").decimalValue() == expected)
    #expect(try JSONNumberLiteral(expected).rawValue == "9.27")
    for text in [
      "0", "-0", "-9.27", "12345678901234567890123456789012345678",
      "9007199254740993", "340282366920938463463374607431768211455",
      "340282366920938463463374607431768211455e127", "1e128", "1e-128",
      "18446744073709551615e128", "18446744073709551615e146",
      "100e-130", "1.230000000000000000000000000000000000000000000000000000000",
      "0." + String(repeating: "0", count: 200) + "927e203",
    ] {
      let original = try JSONNumberLiteral(text)
      #expect(try JSONNumberLiteral(original.decimalValue()) == original)
    }
    #expect(throws: ConversionError.nonFinite) { try JSONNumberLiteral(Decimal.nan) }
  }

  @Test(arguments: [UInt64(1), UInt64.max], -128 ... 127)
  func compactDecimalConversion(coefficient: UInt64, exponent: Int) throws {
    for sign in ["", "-"] {
      let literal = try JSONNumberLiteral("\(sign)\(coefficient)e\(exponent)")
      #expect(try JSONNumberLiteral(literal.decimalValue()) == literal)
    }
  }

  @Test func decimalConversionRejectsSilentRounding() {
    for text in [
      "1234567890123456789012345678901234567890123456789",
      "0.1234567890123456789012345678901234567890123456789",
      "340282366920938463463374607431768211456", "123e-129",
    ] {
      #expect(throws: ConversionError.inexactConversion) {
        try JSONNumberLiteral(text).decimalValue()
      }
    }
    for text in [
      "1e1000", "1e-400", "1e-129", "1e999999999999999999999999",
      "1e-999999999999999999999999",
    ] {
      #expect(throws: ConversionError.outOfRange) { try JSONNumberLiteral(text).decimalValue() }
    }
  }

  @Test(arguments: [
    ["1", "1.0", "1e0", "10e-1", "0.01e2", "1E+00000"],
    ["0", "-0", "0.000", "-0.00e-999999999999999999999999", "0e999999999999999999999999"],
    ["-12", "-1.2e1", "-1200e-2", "-12.0000"],
    ["1e999999999999999999999999", "10e999999999999999999999998"],
    ["1e-999999999999999999999999", "10e-1000000000000000000000000"],
    ["18446744073709551615", "184467440737095516150e-1", "18446744073709551615.000"],
    ["18446744073709551616", "1844674407370955161600e-2", "18446744073709551616.0"],
    ["1e9223372036854775807", "0.1e9223372036854775808", "10e9223372036854775806"],
    ["1e9223372036854775808", "10e9223372036854775807", "100e9223372036854775806"],
    ["1e-9223372036854775808", "10e-9223372036854775809", "0.1e-9223372036854775807"],
    ["1e-9223372036854775809", "0.1e-9223372036854775808", "10e-9223372036854775810"],
  ])
  func normalizedEqualityAndHash(_ spellings: [String]) throws {
    let values = try spellings.map { try JSONNumberLiteral($0) }
    #expect(Set(values).count == 1)
    for left in values {
      for right in values {
        #expect(left == right)
        #expect(!(left < right))
        #expect(left.hashValue == right.hashValue)
      }
    }
  }

  @Test func exactOrdering() throws {
    let spellings = [
      "-1e999999999999999999999999", "-2e1000", "-1e1000", "-1234", "-12.001",
      "-12", "-1", "-1e-999999999999999999999999", "0",
      "1e-1000000000000000000000000", "1e-999999999999999999999999",
      "0.001", "0.01", "1", "1.001", "1.01", "1.1", "2", "10", "100.1",
      "9007199254740992", "9007199254740993", "9223372036854775808",
      "12345678901234567890123456789012345678901234567890", "1e1000", "2e1000",
      "9e999999999999999999999998", "1e999999999999999999999999",
      "1.01e999999999999999999999999", "1e1000000000000000000000000",
    ]
    let values = try spellings.map { try JSONNumberLiteral($0) }
    for left in values.indices {
      for right in values.indices {
        #expect((values[left] < values[right]) == (left < right))
      }
    }
    #expect(values.reversed().sorted() == values)
  }

  @Test func veryLongExponentNormalization() throws {
    let exponent = String(repeating: "9", count: 10_000)
    let nextExponent = "1" + String(repeating: "0", count: 10_000)
    let huge = try JSONNumberLiteral("10e" + exponent)
    #expect(try huge == JSONNumberLiteral("1e" + nextExponent))
    let tiny = try JSONNumberLiteral("0.1e-" + exponent)
    #expect(try tiny == JSONNumberLiteral("1e-" + nextExponent))
    #expect(tiny < huge)
    #expect(Set([huge, tiny]).count == 2)
  }

  @Test(arguments: [
    ("0.3", "0.1", true), ("1", "0.3", false), ("1e1000", "3", false),
    ("1e1000", "2", true), ("1e1000", "5", true), ("1", "0.5", true),
    ("-0.3", "0.1", true), ("0", "3", true), ("-0", "3", true),
    ("123456789012345678901234567890", "3", true),
    ("9007199254740993", "2", false), ("100", "4", true), ("1", "4", false),
    ("12", "6", true), ("3", "6", false), ("30", "6", true), ("15", "25", false),
    ("150", "25", true), ("35", "7", true), ("36", "7", false), ("1", "1e1000", false),
    ("1e999999999999999999999999", "8", true),
    ("1e999999999999999999999999", "7", false),
    ("1e-999999999999999999999999", "1e-1000000000000000000000000", true),
    ("1e-1000000000000000000000000", "1e-999999999999999999999999", false),
    ("18446744073709551615", "3", true),
    ("18446744073709551615", "7", false),
    ("18446744073709551616", "2", true),
    ("18446744073709551616", "3", false),
    ("18446744073709551615e20", "18446744073709551615", true),
    ("18446744073709551615", "18446744073709551616", false),
    ("1", "0.0000000000000000000542101086242752217003726400434970855712890625", true),
    ("1e20", "18446744073709551615", false),
    ("1e19", "9223372036854775808", false),
    ("1e63", "9223372036854775808", true),
    ("1e27", "7450580596923828125", true),
    ("1e26", "7450580596923828125", false),
    ("3e63", "13835058055282163712", true),
    ("1e9223372036854775807", "1e-9223372036854775808", true),
    ("1e-9223372036854775808", "1e9223372036854775807", false),
    ("1e9223372036854775807", "7e-9223372036854775808", false),
    ("1e9223372036854775807", "8e-9223372036854775808", true),
  ])
  func exactDivisibility(_ numerator: String, _ denominator: String, _ expected: Bool) throws {
    #expect(
      try JSONNumberLiteral(numerator).isMultiple(of: JSONNumberLiteral(denominator)) == expected
    )
  }

  @Test func divisibilityAgreesWithIntegerArithmetic() throws {
    for numerator in -60 ... 60 {
      for denominator in 1 ... 30 {
        for numeratorScale in -2 ... 2 {
          for denominatorScale in -2 ... 2 {
            let left = try JSONNumberLiteral("\(numerator)e\(numeratorScale)")
            let right = try JSONNumberLiteral("\(denominator)e\(denominatorScale)")
            let powers = [1, 10, 100, 1_000, 10_000]
            let scaledNumerator = numerator * powers[numeratorScale + 2]
            let scaledDenominator = denominator * powers[denominatorScale + 2]
            #expect(try left.isMultiple(of: right) == (scaledNumerator % scaledDenominator == 0))
          }
        }
      }
    }
  }

  @Test(arguments: ["0", "-0", "0e1000", "-1", "-0.1", "-1e-1000"])
  func nonPositiveDivisors(_ text: String) throws {
    let divisor = try JSONNumberLiteral(text)
    for numerator in [JSONNumberLiteral(0), JSONNumberLiteral(1)] {
      #expect(throws: ConversionError.nonPositiveDivisor) { try numerator.isMultiple(of: divisor) }
    }
  }

  @Test func compactStorageDoesNotEnlargeJSONValues() {
    #expect(MemoryLayout<JSONNumberLiteral>.size == MemoryLayout<String>.size)
    #expect(MemoryLayout<JSONValue>.stride <= 32)
  }

  @Test func longTokensNormalizeWithoutLosingDigits() throws {
    let zeros = String(repeating: "0", count: 10_000)
    let spellings = [
      ("1." + zeros, "1"),
      ("18446744073709551615." + zeros, "18446744073709551615"),
      ("18446744073709551616." + zeros, "18446744073709551616"),
      ("0." + zeros + "927e10003", "927"),
      ("927" + zeros + "e-10000", "927"),
      ("927e+" + zeros, "927"),
      ("-0." + zeros + "e-" + zeros + "1", "0"),
    ]
    for (text, canonical) in spellings {
      let number = try JSONNumberLiteral(text)
      let expected = try JSONNumberLiteral(canonical)
      #expect(number == expected)
      #expect(number.hashValue == expected.hashValue)
      #expect(number.isInteger)
      let parsed = try JSONValue.parse(text)
      #expect(parsed == .numberLiteral(number))
      #expect(try parsed.serialized() == text)
    }
    let huge = try JSONNumberLiteral("1." + zeros + "1")
    #expect(!huge.isInteger)
    #expect(huge > JSONNumberLiteral(1))
    #expect(huge < JSONNumberLiteral(2))
  }

  @Test func orderingAcrossCompactBoundaries() throws {
    let texts = [
      "-1e9223372036854775808", "-1e9223372036854775807",
      "-18446744073709551616", "-18446744073709551615",
      "-1e-9223372036854775808", "-1e-9223372036854775809",
      "0", "1e-9223372036854775809", "1e-9223372036854775808",
      "18446744073709551614", "18446744073709551615", "18446744073709551616",
      "18446744073709551617", "99999999999999999999",
      "1e9223372036854775807", "9e9223372036854775807", "1e9223372036854775808",
    ]
    let values = try texts.map { try JSONNumberLiteral($0) }
    for left in values.indices {
      for right in values.indices {
        #expect((values[left] < values[right]) == (left < right))
        #expect((values[left] == values[right]) == (left == right))
      }
    }
  }

  @Test func fullWidthCoefficientsAgreeWithUnsignedArithmetic() throws {
    var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    for _ in 0 ..< 256 {
      state = state &* 6_364_136_223_846_793_005 &+ 1
      let numerator = state
      state = state &* 6_364_136_223_846_793_005 &+ 1
      for denominator in [UInt64(1), 2, 3, 5, 9, UInt64.max, state | 1] {
        for scale in [-129, -2, 0, 2, 129] {
          let left = try JSONNumberLiteral("\(numerator)e\(scale)")
          let right = try JSONNumberLiteral("\(denominator)e\(scale)")
          #expect(try left.isMultiple(of: right) == (numerator % denominator == 0))
          #expect((left < right) == (numerator < denominator))
          #expect((left == right) == (numerator == denominator))
          let equivalent = try JSONNumberLiteral("\(numerator)0e\(scale - 1)")
          #expect(left == equivalent)
          #expect(left.hashValue == equivalent.hashValue)
        }
      }
    }
  }

  @Test func arithmeticResourceLimitsAreExplicit() throws {
    let large = try JSONNumberLiteral(String(repeating: "1", count: 4_097))
    #expect(throws: ConversionError.arithmeticResourceLimit) {
      try large.isMultiple(of: JSONNumberLiteral(3))
    }
    #expect(throws: ConversionError.arithmeticResourceLimit) {
      try JSONNumberLiteral(3).isMultiple(of: large)
    }
    let numerator = try JSONNumberLiteral(String(repeating: "9", count: 4_096))
    let denominator = try JSONNumberLiteral("1" + String(repeating: "0", count: 2_046) + "1")
    #expect(throws: ConversionError.arithmeticResourceLimit) {
      try numerator.isMultiple(of: denominator)
    }
    #expect(try large.isMultiple(of: large))
    #expect(try large.isMultiple(of: JSONNumberLiteral(1)))
    #expect(try JSONNumberLiteral(0).isMultiple(of: large))
    #expect(large > JSONNumberLiteral(1))
    #expect(large.isInteger)
  }

  @Test func errorsHaveDescriptions() {
    for error in [
      ConversionError.invalidLiteral("NaN"), .nonFinite, .outOfRange, .inexactConversion,
      .arithmeticResourceLimit, .nonPositiveDivisor,
    ] {
      #expect(!error.description.isEmpty)
    }
  }

  @Test(arguments: [
    "9.27", "-123.41666699999999", "-65.613616999999977", "43.420273000000009",
    "9.270000000000000001", "9007199254740993.25",
    "1.0000000000000001", "-1.0000000000000001", "9223372036854775806.5",
    "12345678901234567890.123456789012345678", "1e-128", "1e128",
    "340282366920938463463374607431768211455",
  ])
  func codablePreservesExactJSONNumbers(_ text: String) throws {
    let original = try JSONNumberLiteral(text)
    let encoded = try JSONEncoder().encode(original)
    #expect(try JSONValue.parse(encoded).numberLiteral == original)
    #expect(try JSONDecoder().decode(JSONNumberLiteral.self, from: Data(text.utf8)) == original)
    #expect(try JSONDecoder().decode(JSONNumberLiteral.self, from: encoded) == original)
    let value = JSONValue.numberLiteral(original)
    #expect(try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)) == value)
    #expect(try JSONValue.parse(JSONEncoder().encode(value)) == value)
  }
}
