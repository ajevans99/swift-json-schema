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
      (7, 0.3, false)  // Edge case: integer value not valid for decimal multipleOf
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
}
