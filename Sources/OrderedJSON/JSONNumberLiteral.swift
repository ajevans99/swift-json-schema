import Foundation

/// A validated JSON number whose original spelling and exact decimal value are preserved.
///
/// Equality, hashing, ordering, and integrality use the mathematical value, not its spelling.
/// Exponents may contain arbitrarily many digits; these operations never expand powers of ten.
public struct JSONNumberLiteral: Hashable, Comparable, Sendable, CustomStringConvertible {
  public let rawValue: String

  private let negative: Bool
  private let coefficient: [UInt8]
  private let exponent: JSONNumberExponent

  public enum ConversionError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidLiteral(String)
    case nonFinite
    case outOfRange
    case inexactConversion
    case arithmeticResourceLimit
    case nonPositiveDivisor

    public var description: String {
      switch self {
      case .invalidLiteral(let literal):
        return "Invalid JSON number literal: \(literal)"
      case .nonFinite:
        return "JSON numbers cannot represent NaN or infinity."
      case .outOfRange:
        return "The JSON number is outside the destination type's finite, nonzero range."
      case .inexactConversion:
        return "The destination type cannot represent the JSON number exactly."
      case .arithmeticResourceLimit:
        return "Exact divisibility exceeded its coefficient-size or arithmetic-work limit."
      case .nonPositiveDivisor:
        return "A multiple-of divisor must be strictly positive."
      }
    }
  }

  /// Validates the complete RFC 8259 number grammar, without accepting surrounding whitespace.
  public init(_ rawValue: String) throws {
    let bytes = Array(rawValue.utf8)
    var index = 0
    let negative = bytes.first == 45
    if negative { index += 1 }
    let start = index

    guard index < bytes.count else { throw ConversionError.invalidLiteral(rawValue) }
    if bytes[index] == 48 {
      index += 1
    } else {
      guard (49 ... 57).contains(bytes[index]) else {
        throw ConversionError.invalidLiteral(rawValue)
      }
      while index < bytes.count, (48 ... 57).contains(bytes[index]) { index += 1 }
    }
    var coefficient = bytes[start ..< index].map { $0 - 48 }
    var fractionCount = 0
    if index < bytes.count, bytes[index] == 46 {
      index += 1
      let fractionStart = index
      while index < bytes.count, (48 ... 57).contains(bytes[index]) { index += 1 }
      fractionCount = index - fractionStart
      guard fractionCount > 0 else { throw ConversionError.invalidLiteral(rawValue) }
      coefficient.append(contentsOf: bytes[fractionStart ..< index].map { $0 - 48 })
    }

    var exponent = JSONNumberExponent(0)
    if index < bytes.count, bytes[index] == 69 || bytes[index] == 101 {
      index += 1
      var exponentNegative = false
      if index < bytes.count, bytes[index] == 43 || bytes[index] == 45 {
        exponentNegative = bytes[index] == 45
        index += 1
      }
      let exponentStart = index
      while index < bytes.count, (48 ... 57).contains(bytes[index]) { index += 1 }
      guard index > exponentStart else { throw ConversionError.invalidLiteral(rawValue) }
      exponent = JSONNumberExponent(
        negative: exponentNegative,
        digits: bytes[exponentStart ..< index].map { $0 - 48 }
      )
    }
    guard index == bytes.count else { throw ConversionError.invalidLiteral(rawValue) }
    self.init(
      rawValue: rawValue,
      negative: negative,
      coefficient: coefficient,
      exponent: exponent.adding(-fractionCount)
    )
  }

  public init(_ value: Int) {
    let text = String(value)
    self.init(
      rawValue: text,
      negative: value < 0,
      coefficient: text.utf8.filter { $0 != 45 }.map { $0 - 48 },
      exponent: JSONNumberExponent(0)
    )
  }

  /// Preserves exact `Int` values with a `.0` suffix, including values near integer boundaries.
  ///
  /// Other finite doubles use their round-trippable decimal spelling, not their exact binary
  /// expansion. Negative zero retains its sign.
  public init(_ value: Double) throws {
    guard value.isFinite else { throw ConversionError.nonFinite }
    if value == 0, value.sign == .minus {
      try self.init("-0.0")
    } else if let integer = Int(exactly: value) {
      try self.init(String(integer) + ".0")
    } else {
      try self.init(String(value))
    }
  }

  /// Uses Foundation's locale-independent decimal spelling and rejects NaN.
  public init(_ value: Decimal) throws {
    guard !value.isNaN else { throw ConversionError.nonFinite }
    var value = value
    try self.init(NSDecimalString(&value, Locale(identifier: "en_US_POSIX")))
  }

  private init(
    rawValue: String,
    negative: Bool,
    coefficient: [UInt8],
    exponent: JSONNumberExponent
  ) {
    self.rawValue = rawValue
    let first = coefficient.firstIndex { $0 != 0 }
    guard let first else {
      self.negative = false
      self.coefficient = []
      self.exponent = JSONNumberExponent(0)
      return
    }
    var end = coefficient.count
    while coefficient[end - 1] == 0 { end -= 1 }
    self.negative = negative
    self.coefficient = Array(coefficient[first ..< end])
    self.exponent = exponent.adding(coefficient.count - end)
  }

  public var description: String { rawValue }
  public var isZero: Bool { coefficient.isEmpty }
  public var isInteger: Bool { isZero || !exponent.negative }

  public func integerValue() throws -> Int {
    guard isInteger else { throw ConversionError.inexactConversion }
    if isZero { return 0 }
    let maximumDigits = String(Int.max).utf8.count
    guard coefficient.count <= maximumDigits,
      exponent <= JSONNumberExponent(maximumDigits - coefficient.count),
      let zeros = exponent.intValue
    else { throw ConversionError.outOfRange }
    let text =
      (negative ? "-" : "") + JSONNumberDigits.text(coefficient)
      + String(repeating: "0", count: zeros)
    guard let value = Int(text) else { throw ConversionError.outOfRange }
    return value
  }

  /// Permits ordinary binary rounding, but rejects overflow and nonzero values rounded to zero.
  public func doubleValue() throws -> Double {
    if isZero { return rawValue.hasPrefix("-") ? -Double.zero : Double.zero }
    guard let value = Double(rawValue), value.isFinite, value != 0 else {
      throw ConversionError.outOfRange
    }
    return value
  }

  /// Converts exactly, rejecting range loss and finite precision loss.
  ///
  /// The normalized value is parsed with the POSIX locale, then compared against the normalized
  /// decimal round-trip. Foundation's otherwise silent decimal rounding is never accepted.
  public func decimalValue() throws -> Decimal {
    if isZero { return .zero }
    let order = exponent.adding(coefficient.count)
    guard order >= JSONNumberExponent(-127), order <= JSONNumberExponent(166) else {
      throw ConversionError.outOfRange
    }
    guard coefficient.count <= 39, exponent >= JSONNumberExponent(-128) else {
      throw ConversionError.inexactConversion
    }
    guard var power = exponent.intValue else { throw ConversionError.outOfRange }
    var digits = JSONNumberDigits.text(coefficient)
    // Decimal's exponent stops at 127, but its mantissa can carry additional powers of ten.
    if power > 127 {
      digits += String(repeating: "0", count: power - 127)
      power = 127
    }
    let text = (negative ? "-" : "") + digits + "e" + String(power)
    guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
      !value.isNaN
    else { throw ConversionError.outOfRange }
    guard try JSONNumberLiteral(value) == self else { throw ConversionError.inexactConversion }
    return value
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.negative == rhs.negative && lhs.coefficient == rhs.coefficient
      && lhs.exponent == rhs.exponent
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(negative)
    hasher.combine(coefficient)
    hasher.combine(exponent)
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    if lhs.negative != rhs.negative { return lhs.negative }
    if lhs.isZero { return !rhs.isZero }
    if rhs.isZero { return false }
    let comparison = magnitudeComparison(lhs, rhs)
    return lhs.negative ? comparison > 0 : comparison < 0
  }

  private static func magnitudeComparison(_ lhs: Self, _ rhs: Self) -> Int {
    let lhsOrder = lhs.exponent.adding(lhs.coefficient.count)
    let rhsOrder = rhs.exponent.adding(rhs.coefficient.count)
    if lhsOrder != rhsOrder { return lhsOrder < rhsOrder ? -1 : 1 }
    for index in 0 ..< max(lhs.coefficient.count, rhs.coefficient.count) {
      let left = index < lhs.coefficient.count ? lhs.coefficient[index] : 0
      let right = index < rhs.coefficient.count ? rhs.coefficient[index] : 0
      if left != right { return left < right ? -1 : 1 }
    }
    return 0
  }

  /// Tests exact mathematical divisibility; the divisor must be strictly positive.
  ///
  /// General arithmetic is limited to 4,096 significant coefficient digits per operand and
  /// 1,000,000 decimal digit work units (division, comparison, and subtraction). Exceeding either
  /// limit throws `ConversionError.arithmeticResourceLimit`. Trivial zero, unit-coefficient,
  /// equal-coefficient, and negative-scale cases do not require general arithmetic.
  ///
  /// Factors of two and five are handled separately so even enormous powers of ten need not
  /// be expanded. No floating-point approximations are used.
  public func isMultiple(of divisor: Self) throws -> Bool {
    guard !divisor.isZero, !divisor.negative else { throw ConversionError.nonPositiveDivisor }
    if isZero { return true }
    let shift = exponent.subtracting(divisor.exponent)
    // A normalized coefficient has no factor of ten, so a negative shift cannot be integral.
    if shift.negative { return false }
    if divisor.coefficient == [1] || coefficient == divisor.coefficient { return true }
    guard coefficient.count <= 4_096, divisor.coefficient.count <= 4_096 else {
      throw ConversionError.arithmeticResourceLimit
    }
    var budget = JSONNumberArithmeticBudget()
    var numerator = coefficient
    var denominator = divisor.coefficient
    for factor: UInt8 in [2, 5] {
      var count = 0
      while let last = denominator.last, last % factor == 0 {
        denominator = try JSONNumberDigits.dividing(denominator, by: factor, budget: &budget)
        count += 1
      }
      if shift < JSONNumberExponent(count) {
        guard let supplied = shift.intValue else { throw ConversionError.arithmeticResourceLimit }
        for _ in supplied ..< count {
          guard let last = numerator.last, last % factor == 0 else { return false }
          numerator = try JSONNumberDigits.dividing(numerator, by: factor, budget: &budget)
        }
      }
    }
    if denominator == [1] { return true }
    return try JSONNumberDigits.remainder(numerator, by: denominator, budget: &budget).isEmpty
  }
}

/// Signed arbitrary-precision decimal integer used only for powers, never expanded values.
private struct JSONNumberExponent: Hashable, Comparable, Sendable {
  let negative: Bool
  let digits: [UInt8]

  init(_ value: Int) {
    self.init(
      negative: value < 0,
      digits: String(value).utf8.filter { $0 != 45 }.map { $0 - 48 }
    )
  }

  init(negative: Bool, digits: [UInt8]) {
    self.digits = Array(digits.drop(while: { $0 == 0 }))
    self.negative = negative && !self.digits.isEmpty
  }

  var intValue: Int? {
    if digits.isEmpty { return 0 }
    return Int((negative ? "-" : "") + JSONNumberDigits.text(digits))
  }

  func adding(_ value: Int) -> Self { adding(Self(value)) }

  private func adding(_ other: Self) -> Self {
    if negative == other.negative {
      return Self(negative: negative, digits: JSONNumberDigits.add(digits, other.digits))
    }
    let comparison = JSONNumberDigits.compare(digits, other.digits)
    if comparison >= 0 {
      return Self(negative: negative, digits: JSONNumberDigits.subtract(digits, other.digits))
    }
    return Self(negative: other.negative, digits: JSONNumberDigits.subtract(other.digits, digits))
  }

  func subtracting(_ other: Self) -> Self {
    adding(Self(negative: !other.negative, digits: other.digits))
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    if lhs.negative != rhs.negative { return lhs.negative }
    let comparison = JSONNumberDigits.compare(lhs.digits, rhs.digits)
    return lhs.negative ? comparison > 0 : comparison < 0
  }
}

private struct JSONNumberArithmeticBudget {
  private var remaining = 1_000_000

  mutating func spend(_ units: Int) throws {
    guard units <= remaining else {
      throw JSONNumberLiteral.ConversionError.arithmeticResourceLimit
    }
    remaining -= units
  }
}

/// Unsigned, big-endian decimal digits; zero is an empty array.
private enum JSONNumberDigits {
  static func text(_ digits: [UInt8]) -> String {
    String(decoding: digits.map { $0 + 48 }, as: UTF8.self)
  }

  static func compare(_ lhs: [UInt8], _ rhs: [UInt8]) -> Int {
    if lhs.count != rhs.count { return lhs.count < rhs.count ? -1 : 1 }
    for (left, right) in zip(lhs, rhs) where left != right {
      return left < right ? -1 : 1
    }
    return 0
  }

  static func add(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
    var result: [UInt8] = []
    var carry: UInt8 = 0
    for offset in 0 ..< max(lhs.count, rhs.count) {
      let left = offset < lhs.count ? lhs[lhs.count - 1 - offset] : 0
      let right = offset < rhs.count ? rhs[rhs.count - 1 - offset] : 0
      let sum = left + right + carry
      result.append(sum % 10)
      carry = sum / 10
    }
    if carry != 0 { result.append(carry) }
    return result.reversed()
  }

  /// Requires lhs >= rhs.
  static func subtract(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
    var result = lhs
    var borrow = 0
    for offset in 0 ..< lhs.count {
      let right = offset < rhs.count ? Int(rhs[rhs.count - 1 - offset]) : 0
      var digit = Int(lhs[lhs.count - 1 - offset]) - right - borrow
      borrow = digit < 0 ? 1 : 0
      if digit < 0 { digit += 10 }
      result[lhs.count - 1 - offset] = UInt8(digit)
    }
    return Array(result.drop(while: { $0 == 0 }))
  }

  /// Used only when the coefficient is known to be divisible by two or five.
  static func dividing(
    _ digits: [UInt8],
    by divisor: UInt8,
    budget: inout JSONNumberArithmeticBudget
  ) throws -> [UInt8] {
    try budget.spend(digits.count)
    var result: [UInt8] = []
    result.reserveCapacity(digits.count)
    var remainder: UInt8 = 0
    for digit in digits {
      let value = remainder * 10 + digit
      let quotient = value / divisor
      if !result.isEmpty || quotient != 0 { result.append(quotient) }
      remainder = value % divisor
    }
    return result
  }

  static func remainder(
    _ numerator: [UInt8],
    by denominator: [UInt8],
    budget: inout JSONNumberArithmeticBudget
  ) throws -> [UInt8] {
    var remainder: [UInt8] = []
    for digit in numerator {
      try budget.spend(1)
      if !remainder.isEmpty || digit != 0 { remainder.append(digit) }
      while remainder.count >= denominator.count {
        try budget.spend(denominator.count)
        if compare(remainder, denominator) < 0 { break }
        try budget.spend(remainder.count)
        remainder = subtract(remainder, denominator)
      }
    }
    return remainder
  }
}
