import JSONSchema

extension DefaultValidator {
  public func validate(number: Double, against options: NumberSchemaOptions) -> Validation<Double> {
    let builder = ValidationErrorBuilder()

    if let multipleOf = options.multipleOf {
      if let optionError = validateOption(multipleOf: multipleOf) {
        builder.addError(optionError)
      } else {
        builder.addError(validateMultipleOf(multipleOf: multipleOf, value: number).map { .number(issue: $0, actual: number) })
      }
    }

    builder.addErrors(validateBoundaries(value: number, options: options).map { .number(issue: $0, actual: number) })

    return builder.build(for: number)
  }

  public func validate(integer: Int, against options: NumberSchemaOptions) -> Validation<Int> {
    let builder = ValidationErrorBuilder()

    let number = Double(integer)

    if let multipleOf = options.multipleOf {
      if let optionError = validateOption(multipleOf: multipleOf) {
        builder.addError(optionError)
      } else {
        builder.addError(validateMultipleOf(multipleOf: multipleOf, value: number).map { .integer(issue: $0, actual: integer) })
      }
    }

    builder.addErrors(validateBoundaries(value: number, options: options).map { .integer(issue: $0, actual: integer) })

    return builder.build(for: integer)
  }
}

// MARK: - Helpers

extension DefaultValidator {
  private func validateOption(multipleOf: Double) -> ValidationIssue? {
    let schema = JSONNumber().exclusiveMinimum(0)

    if case let .invalid(optionsErrors) = schema.validate(.number(multipleOf), against: DefaultValidator()) {
      return .invalidOption(option: "multipleOf", issues: optionsErrors)
    }

    return nil
  }

  private func validateMultipleOf(multipleOf: Double, value: Double) -> ValidationIssue.NumberIssue? {
    value.truncatingRemainder(dividingBy: multipleOf) == 0 ? nil : .multipleOf(expected: multipleOf)
  }

  private func validateBoundaries(value: Double, options: NumberSchemaOptions) -> [ValidationIssue.NumberIssue] {
    var errors = [ValidationIssue.NumberIssue]()

    // Validate minimum boundary
    if let minimum = options.minimum {
      switch minimum {
      case .inclusive(let minValue):
        if value < minValue {
          errors.append(.minimum(isInclusive: true, expected: minValue))
        }
      case .exclusive(let minValue):
        if value <= minValue {
          errors.append(.minimum(isInclusive: false, expected: minValue))
        }
      }
    }

    // Validate maximum boundary
    if let maximum = options.maximum {
      switch maximum {
      case .inclusive(let maxValue):
        if value > maxValue {
          errors.append(.maximum(isInclusive: true, expected: maxValue))
        }
      case .exclusive(let maxValue):
        if value >= maxValue {
          errors.append(.maximum(isInclusive: false, expected: maxValue))
        }
      }
    }

    return errors
  }
}
