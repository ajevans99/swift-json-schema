import JSONSchema

extension DefaultValidator {
  public func validate(number: Double, against options: NumberSchemaOptions) -> Validation<Double> {
    let builder = ValidationErrorBuilder()

    let pullback: (ValidationIssue.NumberIssue) -> ValidationIssue = { .number(issue: $0, actual: number) }
    validateMultipleOf(value: number, options: options, builder: builder, pullback: pullback)
    validateBoundaries(value: number, options: options, builder: builder, pullback: pullback)

    return builder.build(for: number)
  }

  public func validate(integer: Int, against options: NumberSchemaOptions) -> Validation<Int> {
    let builder = ValidationErrorBuilder()

    let pullback: (ValidationIssue.NumberIssue) -> ValidationIssue = { .integer(issue: $0, actual: integer) }
    validateMultipleOf(value: Double(integer), options: options, builder: builder, pullback: pullback)
    validateBoundaries(value: Double(integer), options: options, builder: builder, pullback: pullback)

    return builder.build(for: integer)
  }
}

// MARK: - Helpers

extension DefaultValidator {
  private func validateMultipleOf(value: Double, options: NumberSchemaOptions, builder: ValidationErrorBuilder, pullback: (ValidationIssue.NumberIssue) -> ValidationIssue) {
    guard let multipleOf = options.multipleOf else { return }
    let schema = JSONNumber().exclusiveMinimum(0)

    switch schema.validate(multipleOf, against: self) {
    case .valid(let multipleOf):
      if value.truncatingRemainder(dividingBy: multipleOf) != 0 {
        builder.addError(pullback(.multipleOf(expected: multipleOf)))
      }
    case .invalid(let errors):
      builder.addError(.invalidOption(option: "multipleOf", issues: errors))
    }
  }

  private func validateBoundaries(value: Double, options: NumberSchemaOptions, builder: ValidationErrorBuilder, pullback: (ValidationIssue.NumberIssue) -> ValidationIssue) {
    let schema = JSONNumber()

    func validateBoundary(
      boundary: JSONValue?,
      optionName: String,
      onValid: (Double) -> Void
    ) {
      guard let boundary else { return }

      switch schema.validate(boundary, against: self) {
      case .valid(let double):
        onValid(double)
      case .invalid(let errors):
        builder.addError(.invalidOption(option: optionName, issues: errors))
      }
    }

    validateBoundary(
      boundary: options.minimum,
      optionName: "minimum"
    ) { minimum in
      if value < minimum {
        builder.addError(pullback(.minimum(isInclusive: true, expected: minimum)))
      }
    }

    validateBoundary(
      boundary: options.exclusiveMinimum,
      optionName: "exclusiveMinimum"
    ) { minimum in
      if value <= minimum {
        builder.addError(pullback(.minimum(isInclusive: false, expected: minimum)))
      }
    }

    validateBoundary(
      boundary: options.maximum,
      optionName: "maximum"
    ) { maximum in
      if value > maximum {
        builder.addError(pullback(.maximum(isInclusive: true, expected: maximum)))
      }
    }

    validateBoundary(
      boundary: options.exclusiveMaximum,
      optionName: "exclusiveMaximum"
    ) { maximum in
      if value >= maximum {
        builder.addError(pullback(.maximum(isInclusive: false, expected: maximum)))
      }
    }
  }
}
