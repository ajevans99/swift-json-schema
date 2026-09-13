import Foundation

/// A validated JSON number whose original spelling and exact decimal value are preserved.
///
/// Equality, hashing, ordering, and integrality use the mathematical value, not its spelling.
/// Exponents may contain arbitrarily many digits; these operations never expand powers of ten.
public struct JSONNumberLiteral: Hashable, Comparable, Sendable, CustomStringConvertible {
  public let rawValue: String

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
    let bytes = rawValue.utf8
    var index = bytes.startIndex
    let end = bytes.endIndex
    if index != end, bytes[index] == 45 { bytes.formIndex(after: &index) }
    guard index != end else { throw ConversionError.invalidLiteral(rawValue) }
    if bytes[index] == 48 {
      bytes.formIndex(after: &index)
    } else {
      guard (49 ... 57).contains(bytes[index]) else {
        throw ConversionError.invalidLiteral(rawValue)
      }
      repeat {
        bytes.formIndex(after: &index)
      } while index != end && (48 ... 57).contains(bytes[index])
    }
    if index != end, bytes[index] == 46 {
      bytes.formIndex(after: &index)
      let fractionStart = index
      while index != end, (48 ... 57).contains(bytes[index]) {
        bytes.formIndex(after: &index)
      }
      guard index != fractionStart else { throw ConversionError.invalidLiteral(rawValue) }
    }
    if index != end, bytes[index] == 69 || bytes[index] == 101 {
      bytes.formIndex(after: &index)
      if index != end, bytes[index] == 43 || bytes[index] == 45 {
        bytes.formIndex(after: &index)
      }
      let exponentStart = index
      while index != end, (48 ... 57).contains(bytes[index]) {
        bytes.formIndex(after: &index)
      }
      guard index != exponentStart else { throw ConversionError.invalidLiteral(rawValue) }
    }
    guard index == end else { throw ConversionError.invalidLiteral(rawValue) }
    self.init(validatedLiteral: rawValue)
  }

  /// The caller must have already established the complete JSON number grammar.
  internal init(validatedLiteral: String) {
    rawValue = validatedLiteral
  }

  public init(_ value: Int) {
    self.init(validatedLiteral: String(value))
  }

  /// Preserves exact `Int` values with a `.0` suffix, including values near integer boundaries.
  ///
  /// Other finite doubles use their round-trippable decimal spelling, not their exact binary
  /// expansion. Negative zero retains its sign.
  public init(_ value: Double) throws {
    guard value.isFinite else { throw ConversionError.nonFinite }
    if value == 0, value.sign == .minus {
      self.init(validatedLiteral: "-0.0")
    } else if let integer = Int(exactly: value) {
      self.init(validatedLiteral: String(integer) + ".0")
    } else {
      self.init(validatedLiteral: String(value))
    }
  }

  /// Uses Foundation's locale-independent decimal spelling and rejects NaN.
  public init(_ value: Decimal) throws {
    guard !value.isNaN else { throw ConversionError.nonFinite }
    self.init(validatedLiteral: value.description)
  }

  public var description: String { rawValue }
  public var isZero: Bool { JSONNumberNormalized(rawValue).isZero }
  public var isInteger: Bool { JSONNumberNormalized(rawValue).isInteger }

  public func integerValue() throws -> Int {
    try JSONNumberNormalized(rawValue).integerValue()
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
  /// Uses checked decimal arithmetic for compact values. Larger values use a POSIX-locale parse
  /// and an exact decimal round-trip check. Foundation's silent decimal rounding is never accepted.
  public func decimalValue() throws -> Decimal {
    try JSONNumberNormalized(rawValue).decimalValue()
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    JSONNumberNormalized(lhs.rawValue) == JSONNumberNormalized(rhs.rawValue)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(JSONNumberNormalized(rawValue))
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    JSONNumberNormalized(lhs.rawValue) < JSONNumberNormalized(rhs.rawValue)
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
    try JSONNumberNormalized(rawValue).isMultiple(of: JSONNumberNormalized(divisor.rawValue))
  }
}

/// Canonical transient metadata. Only values outside the compact range allocate digit arrays.
private enum JSONNumberNormalized: Hashable, Comparable {
  case compact(JSONNumberCompact)
  case arbitrary(JSONNumberArbitrary)

  init(_ rawValue: String) {
    if let value = JSONNumberCompact(rawValue) {
      self = .compact(value)
    } else {
      let value = JSONNumberArbitrary(rawValue)
      // An out-of-range written exponent can become compact after normalization.
      if let compact = value.compactValue {
        self = .compact(compact)
      } else {
        self = .arbitrary(value)
      }
    }
  }

  var isZero: Bool {
    switch self {
    case .compact(let value): return value.coefficient == 0
    case .arbitrary(let value): return value.isZero
    }
  }

  var isInteger: Bool {
    switch self {
    case .compact(let value): return value.exponent >= 0
    case .arbitrary(let value): return value.isInteger
    }
  }

  private var arbitraryValue: JSONNumberArbitrary {
    switch self {
    case .compact(let value): return value.arbitraryValue
    case .arbitrary(let value): return value
    }
  }

  func integerValue() throws -> Int {
    switch self {
    case .compact(let value): return try value.integerValue()
    case .arbitrary(let value): return try value.integerValue()
    }
  }

  func decimalValue() throws -> Decimal {
    typealias ConversionError = JSONNumberLiteral.ConversionError
    if isZero { return .zero }
    let negative: Bool
    var digits: String
    var power: Int
    switch self {
    case .compact(let value):
      let order = value.exponent.addingReportingOverflow(value.digitCount)
      guard !order.overflow, (-127 ... 166).contains(order.partialValue) else {
        throw ConversionError.outOfRange
      }
      guard value.exponent >= -128 else { throw ConversionError.inexactConversion }
      if value.exponent <= 127 {
        var significand = Decimal(value.coefficient)
        var decimal = Decimal.zero
        switch NSDecimalMultiplyByPowerOf10(
          &decimal,
          &significand,
          Int16(value.exponent),
          .plain
        ) {
        case .noError:
          return value.negative ? -decimal : decimal
        case .lossOfPrecision:
          throw ConversionError.inexactConversion
        case .underflow, .overflow, .divideByZero:
          throw ConversionError.outOfRange
        @unknown default:
          throw ConversionError.inexactConversion
        }
      }
      negative = value.negative
      digits = String(value.coefficient)
      power = value.exponent
    case .arbitrary(let value):
      let order = value.exponent.adding(value.coefficient.count)
      guard order >= JSONNumberExponent(-127), order <= JSONNumberExponent(166) else {
        throw ConversionError.outOfRange
      }
      guard value.coefficient.count <= 39, value.exponent >= JSONNumberExponent(-128) else {
        throw ConversionError.inexactConversion
      }
      guard let exponent = value.exponent.intValue else { throw ConversionError.outOfRange }
      negative = value.negative
      digits = JSONNumberDigits.text(value.coefficient)
      power = exponent
    }
    // Decimal's exponent stops at 127, but its mantissa can carry additional powers of ten.
    if power > 127 {
      digits += String(repeating: "0", count: power - 127)
      power = 127
    }
    let text = (negative ? "-" : "") + digits + "e" + String(power)
    guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
      !value.isNaN
    else { throw ConversionError.outOfRange }
    guard try Self(JSONNumberLiteral(value).rawValue) == self else {
      throw ConversionError.inexactConversion
    }
    return value
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    if case .compact(let left) = lhs, case .compact(let right) = rhs {
      return left < right
    }
    return lhs.arbitraryValue < rhs.arbitraryValue
  }

  func isMultiple(of divisor: Self) throws -> Bool {
    if case .compact(let numerator) = self, case .compact(let denominator) = divisor {
      return try numerator.isMultiple(of: denominator)
    }
    return try arbitraryValue.isMultiple(of: divisor.arbitraryValue)
  }
}

private struct JSONNumberCompact: Hashable, Comparable {
  let negative: Bool
  let coefficient: UInt64
  let exponent: Int
  let digitCount: Int

  init(negative: Bool, coefficient: UInt64, exponent: Int, digitCount: Int) {
    self.negative = negative
    self.coefficient = coefficient
    self.exponent = exponent
    self.digitCount = digitCount
  }

  /// The token is already valid. Defer zeroes so long, insignificant suffixes stay compact.
  init?(_ rawValue: String) {
    let bytes = rawValue.utf8
    var index = bytes.startIndex
    let end = bytes.endIndex
    let negative = bytes[index] == 45
    if negative { bytes.formIndex(after: &index) }
    var coefficient: UInt64 = 0
    var digitCount = 0
    var pendingZeros = 0
    var fractionCount = 0
    var inFraction = false
    while index != end {
      let byte = bytes[index]
      if byte == 69 || byte == 101 { break }
      bytes.formIndex(after: &index)
      if byte == 46 {
        inFraction = true
        continue
      }
      if inFraction { fractionCount += 1 }
      if byte == 48 {
        if coefficient != 0 { pendingZeros += 1 }
        continue
      }
      // Any intervening zeroes are significant; at most 20 digits fit in UInt64.
      guard pendingZeros <= 19 else { return nil }
      for _ in 0 ..< pendingZeros {
        let product = coefficient.multipliedReportingOverflow(by: 10)
        guard !product.overflow else { return nil }
        coefficient = product.partialValue
      }
      let product = coefficient.multipliedReportingOverflow(by: 10)
      let sum = product.partialValue.addingReportingOverflow(UInt64(byte - 48))
      guard !product.overflow, !sum.overflow else { return nil }
      coefficient = sum.partialValue
      digitCount += pendingZeros + 1
      pendingZeros = 0
    }
    if coefficient == 0 {
      self.init(negative: false, coefficient: 0, exponent: 0, digitCount: 0)
      return
    }
    var exponent = 0
    if index != end {
      bytes.formIndex(after: &index)
      let exponentNegative = bytes[index] == 45
      if bytes[index] == 43 || exponentNegative { bytes.formIndex(after: &index) }
      while index != end {
        let product = exponent.multipliedReportingOverflow(by: 10)
        let digit = Int(bytes[index] - 48)
        // Accumulate negative powers negatively so Int.min remains representable.
        let sum =
          exponentNegative
          ? product.partialValue.subtractingReportingOverflow(digit)
          : product.partialValue.addingReportingOverflow(digit)
        guard !product.overflow, !sum.overflow else { return nil }
        exponent = sum.partialValue
        bytes.formIndex(after: &index)
      }
    }
    let adjusted = exponent.addingReportingOverflow(pendingZeros - fractionCount)
    guard !adjusted.overflow else { return nil }
    self.init(
      negative: negative,
      coefficient: coefficient,
      exponent: adjusted.partialValue,
      digitCount: digitCount
    )
  }

  var arbitraryValue: JSONNumberArbitrary {
    JSONNumberArbitrary(
      negative: negative,
      coefficient: coefficient == 0 ? [] : String(coefficient).utf8.map { $0 - 48 },
      exponent: JSONNumberExponent(exponent)
    )
  }

  func integerValue() throws -> Int {
    typealias ConversionError = JSONNumberLiteral.ConversionError
    guard exponent >= 0 else { throw ConversionError.inexactConversion }
    if coefficient == 0 { return 0 }
    guard exponent < Int.bitWidth else { throw ConversionError.outOfRange }
    var magnitude = coefficient
    for _ in 0 ..< exponent {
      let product = magnitude.multipliedReportingOverflow(by: 10)
      guard !product.overflow else { throw ConversionError.outOfRange }
      magnitude = product.partialValue
    }
    if negative, magnitude == UInt64(Int.min.magnitude) { return Int.min }
    guard let value = Int(exactly: magnitude) else { throw ConversionError.outOfRange }
    return negative ? -value : value
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    if lhs.negative != rhs.negative { return lhs.negative }
    if lhs.coefficient == 0 { return rhs.coefficient != 0 }
    if rhs.coefficient == 0 { return false }
    let leftOrder = lhs.exponent.addingReportingOverflow(lhs.digitCount)
    let rightOrder = rhs.exponent.addingReportingOverflow(rhs.digitCount)
    guard !leftOrder.overflow, !rightOrder.overflow else {
      return lhs.arbitraryValue < rhs.arbitraryValue
    }
    let comparison: Int
    if leftOrder.partialValue != rightOrder.partialValue {
      comparison = leftOrder.partialValue < rightOrder.partialValue ? -1 : 1
    } else {
      comparison = coefficientComparison(lhs, rhs)
    }
    return lhs.negative ? comparison > 0 : comparison < 0
  }

  private static func coefficientComparison(_ lhs: Self, _ rhs: Self) -> Int {
    var left = lhs.coefficient
    var right = rhs.coefficient
    for _ in 0 ..< max(0, rhs.digitCount - lhs.digitCount) {
      let product = left.multipliedReportingOverflow(by: 10)
      if product.overflow { return 1 }
      left = product.partialValue
    }
    for _ in 0 ..< max(0, lhs.digitCount - rhs.digitCount) {
      let product = right.multipliedReportingOverflow(by: 10)
      if product.overflow { return -1 }
      right = product.partialValue
    }
    return left == right ? 0 : (left < right ? -1 : 1)
  }

  func isMultiple(of divisor: Self) throws -> Bool {
    guard divisor.coefficient != 0, !divisor.negative else {
      throw JSONNumberLiteral.ConversionError.nonPositiveDivisor
    }
    if coefficient == 0 { return true }
    let shift = exponent.subtractingReportingOverflow(divisor.exponent)
    guard !shift.overflow else {
      return try arbitraryValue.isMultiple(of: divisor.arbitraryValue)
    }
    if shift.partialValue < 0 { return false }
    if divisor.coefficient == 1 || coefficient == divisor.coefficient { return true }
    var numerator = coefficient
    var denominator = divisor.coefficient
    guard
      supplyFactor(2, shift: shift.partialValue, numerator: &numerator, denominator: &denominator),
      supplyFactor(5, shift: shift.partialValue, numerator: &numerator, denominator: &denominator)
    else { return false }
    return numerator % denominator == 0
  }

  private func supplyFactor(
    _ factor: UInt64,
    shift: Int,
    numerator: inout UInt64,
    denominator: inout UInt64
  ) -> Bool {
    var count = 0
    while denominator % factor == 0 {
      denominator /= factor
      count += 1
    }
    if shift < count {
      for _ in shift ..< count {
        guard numerator % factor == 0 else { return false }
        numerator /= factor
      }
    }
    return true
  }
}

/// Arbitrary-precision fallback; all coefficients and exponents are normalized.
private struct JSONNumberArbitrary: Hashable, Comparable {
  private typealias ConversionError = JSONNumberLiteral.ConversionError

  let negative: Bool
  let coefficient: [UInt8]
  let exponent: JSONNumberExponent

  init(negative: Bool, coefficient: [UInt8], exponent: JSONNumberExponent) {
    self.negative = negative
    self.coefficient = coefficient
    self.exponent = exponent
  }

  init(_ rawValue: String) {
    let bytes = rawValue.utf8
    var index = bytes.startIndex
    let end = bytes.endIndex
    let negative = bytes[index] == 45
    if negative { bytes.formIndex(after: &index) }
    var coefficient: [UInt8] = []
    var fractionCount = 0
    var inFraction = false
    while index != end {
      let byte = bytes[index]
      if byte == 69 || byte == 101 { break }
      bytes.formIndex(after: &index)
      if byte == 46 {
        inFraction = true
      } else {
        coefficient.append(byte - 48)
        if inFraction { fractionCount += 1 }
      }
    }
    var exponent = JSONNumberExponent(0)
    if index != end {
      bytes.formIndex(after: &index)
      let exponentNegative = bytes[index] == 45
      if bytes[index] == 43 || exponentNegative { bytes.formIndex(after: &index) }
      exponent = JSONNumberExponent(
        negative: exponentNegative,
        digits: bytes[index ..< end].map { $0 - 48 }
      )
    }
    guard let first = coefficient.firstIndex(where: { $0 != 0 }) else {
      self.init(negative: false, coefficient: [], exponent: JSONNumberExponent(0))
      return
    }
    var coefficientEnd = coefficient.count
    while coefficient[coefficientEnd - 1] == 0 { coefficientEnd -= 1 }
    self.init(
      negative: negative,
      coefficient: Array(coefficient[first ..< coefficientEnd]),
      exponent: exponent.adding((coefficient.count - coefficientEnd) - fractionCount)
    )
  }

  var compactValue: JSONNumberCompact? {
    guard coefficient.count <= 20, let exponent = exponent.intValue else { return nil }
    var magnitude: UInt64 = 0
    for digit in coefficient {
      let product = magnitude.multipliedReportingOverflow(by: 10)
      let sum = product.partialValue.addingReportingOverflow(UInt64(digit))
      guard !product.overflow, !sum.overflow else { return nil }
      magnitude = sum.partialValue
    }
    return JSONNumberCompact(
      negative: negative,
      coefficient: magnitude,
      exponent: exponent,
      digitCount: coefficient.count
    )
  }

  var isZero: Bool { coefficient.isEmpty }
  var isInteger: Bool { isZero || !exponent.negative }

  func integerValue() throws -> Int {
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

  static func < (lhs: Self, rhs: Self) -> Bool {
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

  func isMultiple(of divisor: Self) throws -> Bool {
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
