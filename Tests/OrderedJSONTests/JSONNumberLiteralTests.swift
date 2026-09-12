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
      "100e-130", "1.230000000000000000000000000000000000000000000000000000000",
      "0." + String(repeating: "0", count: 200) + "927e203",
    ] {
      let original = try JSONNumberLiteral(text)
      #expect(try JSONNumberLiteral(original.decimalValue()) == original)
    }
    #expect(throws: ConversionError.nonFinite) { try JSONNumberLiteral(Decimal.nan) }
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
}
