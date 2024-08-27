import JSONSchema
import Testing

@testable import JSONSchemaBuilder

struct DefaultValidatorTests {
  struct NumberTests {
    let validator = DefaultValidator()

    @Test(arguments: [
      (1.0, 1.0, true),
      (15.0, 5.0, true),
      (15.0, 3.0, true),
      (15.0, 2.0, false),
      (0.0, 2.0, true),  // Edge case: zero value, valid for any multipleOf
      (-6.0, 3.0, true), // Edge case: negative number valid multipleOf
      (10.5, 0.5, true), // Edge case: decimal valid multipleOf
      (10.3, 0.5, false) // Edge case: decimal invalid multipleOf
    ])
    func multipleOf(value: Double, multipleOf: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(multipleOf: multipleOf)
      let expectedResult: Validation<Double> = isValid ? .valid(value) : .error(.number(issue: .multipleOf(expected: multipleOf), actual: value))
      #expect(validator.validate(number: value, against: options) == expectedResult)
    }

    @Test(arguments: [0.0, -0.5, -2.0])
    func invalidMultipleOf(multipleOf: Double) {
      let options = NumberSchemaOptions.options(multipleOf: multipleOf)
      #expect(validator.validate(number: 4, against: options) == .error(.invalidOption(option: "multipleOf", issues: [.number(issue: .minimum(isInclusive: false, expected: 0), actual: multipleOf)])))
    }

    @Test(arguments: [
      (5.0, 5.0, true),
      (4.9, 5.0, false),
      (0.0, 0.0, true),  // Edge case: zero value at inclusive boundary
      (-1.0, 0.0, false) // Edge case: negative value below minimum
    ])
    func inclusiveMinimumBoundary(value: Double, minimum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(minimum: .inclusive(minimum))
      let expectedResult: Validation<Double> = isValid ? .valid(value) : .error(.number(issue: .minimum(isInclusive: true, expected: minimum), actual: value))
      #expect(validator.validate(number: value, against: options) == expectedResult)
    }

    @Test(arguments: [
      (5.1, 5.0, true),
      (5.0, 5.0, false),
      (0.1, 0.0, true),  // Edge case: just above exclusive boundary
      (0.0, 0.0, false)  // Edge case: zero value at exclusive boundary
    ])
    func exclusiveMinimumBoundary(value: Double, minimum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(minimum: .exclusive(minimum))
      let expectedResult: Validation<Double> = isValid ? .valid(value) : .error(.number(issue: .minimum(isInclusive: false, expected: minimum), actual: value))
      #expect(validator.validate(number: value, against: options) == expectedResult)
    }

    @Test(arguments: [
      (5.0, 5.0, true),
      (5.1, 5.0, false),
      (0.0, 0.0, true),  // Edge case: zero value at inclusive boundary
      (1.0, 0.0, false)  // Edge case: value above maximum
    ])
    func inclusiveMaximumBoundary(value: Double, maximum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(maximum: .inclusive(maximum))
      let expectedResult: Validation<Double> = isValid ? .valid(value) : .error(.number(issue: .maximum(isInclusive: true, expected: maximum), actual: value))
      #expect(validator.validate(number: value, against: options) == expectedResult)
    }

    @Test(arguments: [
      (4.9, 5.0, true),
      (5.0, 5.0, false),
      (-0.1, 0.0, true),  // Edge case: just below exclusive boundary
      (0.0, 0.0, false)   // Edge case: zero value at exclusive boundary
    ])
    func exclusiveMaximumBoundary(value: Double, maximum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(maximum: .exclusive(maximum))
      let expectedResult: Validation<Double> = isValid ? .valid(value) : .error(.number(issue: .maximum(isInclusive: false, expected: maximum), actual: value))
      #expect(validator.validate(number: value, against: options) == expectedResult)
    }
  }

  struct IntegerTests {
    let validator = DefaultValidator()

    @Test(arguments: [
      (10, 5.0, true),
      (9, 3.0, true),
      (8, 2.5, false),
      (0, 2.0, true),   // Edge case: zero value, valid for any multipleOf
      (-9, 3.0, true),  // Edge case: negative number valid multipleOf
      (10, 0.5, true),  // Edge case: integer value with decimal multipleOf
      (7, 0.3, false)   // Edge case: integer value not valid for decimal multipleOf
    ])
    func multipleOf(value: Int, multipleOf: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(multipleOf: multipleOf)
      let expectedResult: Validation<Int> = isValid ? .valid(value) : .error(.integer(issue: .multipleOf(expected: multipleOf), actual: value))
      #expect(validator.validate(integer: value, against: options) == expectedResult)
    }

    @Test(arguments: [0.0, -0.5, -2.0])
    func invalidMultipleOf(multipleOf: Double) {
      let options = NumberSchemaOptions.options(multipleOf: multipleOf)
      #expect(validator.validate(integer: 4, against: options) == .error(.invalidOption(option: "multipleOf", issues: [.number(issue: .minimum(isInclusive: false, expected: 0), actual: multipleOf)])))
    }

    @Test(arguments: [
      (5, 5.0, true),
      (4, 5.0, false),
      (0, 0.0, true),   // Edge case: zero value at inclusive boundary
      (-1, 0.0, false)  // Edge case: negative value below minimum
    ])
    func inclusiveMinimumBoundary(value: Int, minimum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(minimum: .inclusive(minimum))
      let expectedResult: Validation<Int> = isValid ? .valid(value) : .error(.integer(issue: .minimum(isInclusive: true, expected: minimum), actual: value))
      #expect(validator.validate(integer: value, against: options) == expectedResult)
    }

    @Test(arguments: [
      (6, 5.0, true),
      (5, 5.0, false),
      (1, 0.0, true),   // Edge case: just above exclusive boundary
      (0, 0.0, false)   // Edge case: zero value at exclusive boundary
    ])
    func exclusiveMinimumBoundary(value: Int, minimum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(minimum: .exclusive(minimum))
      let expectedResult: Validation<Int> = isValid ? .valid(value) : .error(.integer(issue: .minimum(isInclusive: false, expected: minimum), actual: value))
      #expect(validator.validate(integer: value, against: options) == expectedResult)
    }

    @Test(arguments: [
      (5, 5.0, true),
      (6, 5.0, false),
      (0, 0.0, true),   // Edge case: zero value at inclusive boundary
      (1, 0.0, false)   // Edge case: value above maximum
    ])
    func inclusiveMaximumBoundary(value: Int, maximum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(maximum: .inclusive(maximum))
      let expectedResult: Validation<Int> = isValid ? .valid(value) : .error(.integer(issue: .maximum(isInclusive: true, expected: maximum), actual: value))
      #expect(validator.validate(integer: value, against: options) == expectedResult)
    }

    @Test(arguments: [
      (4, 5.0, true),
      (5, 5.0, false),
      (-1, 0.0, true),  // Edge case: just below exclusive boundary
      (0, 0.0, false)   // Edge case: zero value at exclusive boundary
    ])
    func exclusiveMaximumBoundary(value: Int, maximum: Double, isValid: Bool) {
      let options = NumberSchemaOptions.options(maximum: .exclusive(maximum))
      let expectedResult: Validation<Int> = isValid ? .valid(value) : .error(.integer(issue: .maximum(isInclusive: false, expected: maximum), actual: value))
      #expect(validator.validate(integer: value, against: options) == expectedResult)
    }
  }

  struct StringTests {
    let validator = DefaultValidator()

    @Test(arguments: [
      ("hello", 5, true),   // Exact minLength match
      ("hi", 3, false),     // Below minLength
      ("", 0, true),        // Edge case: empty string with minLength 0
      ("abc", 4, false),    // Below minLength
      ("abcd", 4, true)     // Exact minLength match
    ])
    func minLengthValidation(string: String, minLength: Int, isValid: Bool) {
      let options = StringSchemaOptions.options(minLength: minLength)
      let expectedResult: Validation<String> = isValid ? .valid(string) : .error(.string(issue: .minLength(expected: minLength), actual: string))
      #expect(validator.validate(string: string, against: options) == expectedResult)
    }

    @Test(arguments: [
      ("hello", 5, true),         // Exact maxLength match
      ("hello world", 5, false),  // Above maxLength
      ("abc", 3, true),           // Exact maxLength match
      ("abcd", 3, false),         // Above maxLength
      ("", 0, true)               // Edge case: empty string with maxLength 0
    ])
    func maxLengthValidation(string: String, maxLength: Int, isValid: Bool) {
      let options = StringSchemaOptions.options(maxLength: maxLength)
      let expectedResult: Validation<String> = isValid ? .valid(string) : .error(.string(issue: .maxLength(expected: maxLength), actual: string))
      #expect(validator.validate(string: string, against: options) == expectedResult)
    }

    @Test(arguments: [
      ("abc123", "^[a-z]+$", false),  // No match: contains digits
      ("hello", "^[a-z]+$", true),    // Match: only lowercase letters
      ("123", "^[0-9]+$", true),      // Match: only digits
      ("abc!", "^[a-z]+$", false),    // No match: contains special character
      ("", "^.*$", true)              // Edge case: empty string matches any pattern
    ])
    func patternValidation(string: String, pattern: String, isValid: Bool) {
      let options = StringSchemaOptions.options(pattern: pattern)
      let expectedResult: Validation<String> = isValid ? .valid(string) : .error(.string(issue: .pattern(expected: pattern), actual: string))
      #expect(validator.validate(string: string, against: options) == expectedResult)
    }

    @Test(arguments: [
      ("hello", "["),
      ("world", "(")
    ])
    func invalidPatternValidation(string: String, pattern: String) {
      let options = StringSchemaOptions.options(pattern: pattern)
      let expectedResult: Validation<String> = .error(.invalidOption(option: "pattern", issues: [.string(issue: .invalidRegularExpression, actual: pattern)]))
      #expect(validator.validate(string: string, against: options) == expectedResult)
    }

    @Test(arguments: [
      ("2021-08-15", "date", true),           // Format: date
      ("hello@example.com", "email", true),   // Format: email
      ("http://example.com", "uri", true),    // Format: uri
      ("abc", "unknown", true)                // Unknown format (no effect on validation)
    ])
    /// TODO: Allow injecting schema's to validate formats
    func formatValidation(string: String, format: String, isValid: Bool) {
      let options = StringSchemaOptions.options(format: format)
      let expectedResult: Validation<String> = isValid ? .valid(string) : .valid(string)
      #expect(validator.validate(string: string, against: options) == expectedResult)
    }
  }
}
