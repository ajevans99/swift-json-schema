package protocol AssertionKeyword: Keyword {
  func validate(
    _ input: JSONValue,
    at location: JSONPointer,
    using annotations: AnnotationContainer
  ) throws(ValidationIssue)
}

extension Keywords {
  package struct TypeKeyword: AssertionKeyword {
    package static let name = "type"

    package let value: JSONValue
    package let context: KeywordContext

    private let allowedPrimitives: [JSONType]

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      self.allowedPrimitives =
        switch value {
        case .array(let allowedTypes):
          allowedTypes
            .compactMap {
              if case .string(let string) = $0 {
                return string
              }
              return nil
            }
            .compactMap { JSONType(rawValue: $0) }
        case .string(let allowedType):
          JSONType(rawValue: allowedType).map { [$0] } ?? []
        default:
          []
        }
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      let instanceType = input.primitive
      let isValid = allowedPrimitives.contains { allowedType in
        allowedType.matches(instanceType: instanceType)
      }
      if !isValid {
        throw ValidationIssue.typeMismatch(expected: allowedPrimitives, actual: instanceType)
      }
    }
  }

  package struct Enum: AssertionKeyword {
    package static let name = "enum"

    package let value: JSONValue
    package let context: KeywordContext

    private let enumCases: [JSONValue]

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.enumCases = value.array ?? []
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if !enumCases.contains(input) {
        throw ValidationIssue.notEnumCase(value: input, allowedValues: enumCases)
      }
    }
  }

  package struct Constant: AssertionKeyword {
    package static let name = "const"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if input != value {
        throw ValidationIssue.constantMismatch(expected: value, actual: input)
      }
    }
  }
}

// MARK: - Numbers

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-multipleof
  package struct MultipleOf: AssertionKeyword {
    package static let name = "multipleOf"

    package let value: JSONValue
    package let context: KeywordContext

    private let divisor: Double

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      divisor = value.numeric ?? 1.0
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let double = input.numeric {
        // If the divisor is less than 1 and the input is an integer, it is valid.
        if case .integer = input, divisor < 1.0 {
          return
        }

        let remainder = double.remainder(dividingBy: divisor)
        let tolerance = 1e-10  // A small tolerance value to account for floating-point precision
        if abs(remainder) > tolerance {
          throw ValidationIssue.notMultipleOf(number: double, multiple: divisor)
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maximum
  package struct Maximum: AssertionKeyword {
    package static let name = "maximum"

    package let value: JSONValue
    package let context: KeywordContext

    private let maxValue: Double

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxValue = value.numeric ?? .infinity
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number > maxValue {
        throw ValidationIssue.exceedsMaximum(number: number, maximum: maxValue)
      }
    }
  }

  package struct ExclusiveMaximum: AssertionKeyword {
    package static let name = "exclusiveMaximum"

    package let value: JSONValue
    package let context: KeywordContext

    private let exclusiveMaxValue: Double

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.exclusiveMaxValue = value.numeric ?? .infinity
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number >= exclusiveMaxValue {
        throw ValidationIssue.exceedsExclusiveMaximum(number: number, maximum: exclusiveMaxValue)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minimum
  package struct Minimum: AssertionKeyword {
    package static let name = "minimum"

    package let value: JSONValue
    package let context: KeywordContext

    private let minValue: Double

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minValue = value.numeric ?? -.infinity
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number < minValue {
        throw ValidationIssue.belowMinimum(number: number, minimum: minValue)
      }
    }
  }

  package struct ExclusiveMinimum: AssertionKeyword {
    package static let name = "exclusiveMinimum"

    package let value: JSONValue
    package let context: KeywordContext

    private let exclusiveMinValue: Double

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.exclusiveMinValue = value.numeric ?? -.infinity
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number <= exclusiveMinValue {
        throw ValidationIssue.belowExclusiveMinimum(number: number, minimum: exclusiveMinValue)
      }
    }
  }
}

// MARK: - Strings

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxlength
  package struct MaxLength: AssertionKeyword {
    package static let name = "maxLength"

    package let value: JSONValue
    package let context: KeywordContext

    private let maxLength: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxLength = value.integer ?? Int.max
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let string = input.string, string.count > maxLength {
        throw ValidationIssue.exceedsMaxLength(string: string, maxLength: maxLength)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minlength
  package struct MinLength: AssertionKeyword {
    package static let name = "minLength"

    package let value: JSONValue
    package let context: KeywordContext

    private let minLength: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minLength = value.integer ?? 0
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let string = input.string, string.count < minLength {
        throw ValidationIssue.belowMinLength(string: string, minLength: minLength)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-pattern
  package struct Pattern: AssertionKeyword {
    package static let name = "pattern"

    package let value: JSONValue
    package let context: KeywordContext

    nonisolated(unsafe)
      private let regex: Regex<AnyRegexOutput>?

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      if let patternString = value.string {
        self.regex = try? Regex(patternString)
      } else {
        self.regex = nil
      }
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let string = input.string, let regex = regex {
        if string.firstMatch(of: regex) == nil {
          throw ValidationIssue.patternMismatch(string: string, pattern: value.string ?? "")
        }
      }
    }
  }

  package struct Format: AssertionKeyword {
    package static let name = "format"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard
        let formatName = value.string,
        let string = input.string,
        let validator = context.context.formatValidators[formatName]
      else { return }

      if !validator.validate(string) {
        throw ValidationIssue.invalidFormat(name: formatName, value: string)
      }
    }
  }
}

// MARK: - Arrays

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxitems
  package struct MaxItems: AssertionKeyword {
    package static let name = "maxItems"

    package let value: JSONValue
    package let context: KeywordContext

    private let maxItems: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxItems = value.integer ?? Int.max
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let array = input.array, array.count > maxItems {
        throw ValidationIssue.exceedsMaxItems(count: array.count, maxItems: maxItems)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minitems
  package struct MinItems: AssertionKeyword {
    package static let name = "minItems"

    package let value: JSONValue
    package let context: KeywordContext

    private let minItems: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minItems = value.integer ?? 0
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let array = input.array, array.count < minItems {
        throw ValidationIssue.belowMinItems(count: array.count, minItems: minItems)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-uniqueitems
  package struct UniqueItems: AssertionKeyword {
    package static let name = "uniqueItems"

    package let value: JSONValue
    package let context: KeywordContext

    private let uniqueItemsRequired: Bool

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.uniqueItemsRequired = value.boolean ?? false
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if uniqueItemsRequired, let array = input.array {
        let set = Set(array)
        if set.count != array.count {
          throw ValidationIssue.itemsNotUnique
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxcontains
  package struct MaxContains: AssertionKeyword {
    package static let name = "maxContains"

    package let value: JSONValue
    package let context: KeywordContext

    private let maxContains: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxContains = value.integer ?? Int.max
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let array = input.array else { return }

      guard let containsAnnotation = annotations.annotation(for: Contains.self, at: location) else {
        return
      }

      switch containsAnnotation.value {
      case .everyIndex:
        if array.count > maxContains {
          throw ValidationIssue.containsExcessiveMatches(
            count: array.count,
            maxAllowed: maxContains
          )
        }
      case .indicies(let indicies):
        if indicies.count > maxContains {
          throw ValidationIssue.containsExcessiveMatches(
            count: indicies.count,
            maxAllowed: maxContains
          )
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-mincontains
  package struct MinContains: AssertionKeyword {
    package static let name = "minContains"

    package let value: JSONValue
    package let context: KeywordContext

    private let minContains: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minContains = value.integer ?? 1

      if minContains == 0 {
        context.context.minContainsIsZero[context.location.dropLast()] = true
      }
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let array = input.array else { return }

      guard let containsAnnotation = annotations.annotation(for: Contains.self, at: location) else {
        return
      }

      switch containsAnnotation.value {
      case .everyIndex:
        if array.count < minContains {
          throw ValidationIssue.containsInsufficientMatches(
            count: array.count,
            required: minContains
          )
        }
      case .indicies(let indicies):
        if indicies.count < minContains {
          throw ValidationIssue.containsInsufficientMatches(
            count: indicies.count,
            required: minContains
          )
        }
      }
    }
  }
}

// MARK: - Objects

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxproperties
  package struct MaxProperties: AssertionKeyword {
    package static let name = "maxProperties"

    package let value: JSONValue
    package let context: KeywordContext

    private let maxProperties: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxProperties = value.integer ?? Int.max
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let object = input.object else { return }

      if object.count > maxProperties {
        throw ValidationIssue.exceedsMaxProperties(
          count: object.count,
          maxProperties: maxProperties
        )
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minproperties
  package struct MinProperties: AssertionKeyword {
    package static let name = "minProperties"

    package let value: JSONValue
    package let context: KeywordContext

    private let minProperties: Int

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minProperties = value.integer ?? 0
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let object = input.object else { return }

      if object.count < minProperties {
        throw ValidationIssue.belowMinProperties(count: object.count, minProperties: minProperties)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-required
  package struct Required: AssertionKeyword {
    package static let name = "required"

    package let value: JSONValue
    package let context: KeywordContext

    private let requiredKeys: [String]

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.requiredKeys = value.array?.compactMap { $0.string } ?? []
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let object = input.object else { return }

      for key in requiredKeys where !object.keys.contains(key) {
        throw ValidationIssue.missingRequiredProperty(key: key)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-dependentrequired
  package struct DependentRequired: AssertionKeyword {
    package static let name = "dependentRequired"

    package let value: JSONValue
    package let context: KeywordContext

    private let dependencies: [String: [String]]

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.dependencies =
        value.object?.compactMapValues { $0.array?.compactMap { $0.string } } ?? [:]
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let object = input.object else { return }

      for (key, dependentKeys) in dependencies where object.keys.contains(key) {
        for requiredKey in dependentKeys where !object.keys.contains(requiredKey) {
          throw ValidationIssue.missingDependentProperty(key: requiredKey, dependentOn: key)
        }
      }
    }
  }
}
