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
      let instanceType = input.primative
      let isValid = allowedPrimitives.contains { allowedType in
        allowedType.matches(instanceType: instanceType)
      }
      if !isValid {
        throw .typeMismatch
      }
    }
  }

  struct Enum: AssertionKeyword {
    static let name = "enum"

    let value: JSONValue
    let context: KeywordContext

    private let enumCases: [JSONValue]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.enumCases = value.array ?? []
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if !enumCases.contains(input) {
        throw .notEnumCase
      }
    }
  }

  struct Constant: AssertionKeyword {
    static let name = "const"

    let value: JSONValue
    let context: KeywordContext

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if input != value {
        throw .constantMismatch
      }
    }
  }
}

// MARK: - Numbers

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-multipleof
  struct MultipleOf: AssertionKeyword {
    static let name = "multipleOf"

    let value: JSONValue
    let context: KeywordContext

    private let divisor: Double

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      divisor = value.numeric ?? 1.0
    }

    func validate(
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
          throw ValidationIssue.notMultipleOf
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maximum
  struct Maximum: AssertionKeyword {
    static let name = "maximum"

    let value: JSONValue
    let context: KeywordContext

    private let maxValue: Double

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxValue = value.numeric ?? .infinity
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number > maxValue {
        throw .exceedsMaximum
      }
    }
  }

  struct ExclusiveMaximum: AssertionKeyword {
    static let name = "exclusiveMaximum"

    let value: JSONValue
    let context: KeywordContext

    private let exclusiveMaxValue: Double

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.exclusiveMaxValue = value.numeric ?? .infinity
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number >= exclusiveMaxValue {
        throw .exceedsExclusiveMaximum
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minimum
  struct Minimum: AssertionKeyword {
    static let name = "minimum"

    let value: JSONValue
    let context: KeywordContext

    private let minValue: Double

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minValue = value.numeric ?? -.infinity
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number < minValue {
        throw .belowMinimum
      }
    }
  }

  struct ExclusiveMinimum: AssertionKeyword {
    static let name = "exclusiveMinimum"

    let value: JSONValue
    let context: KeywordContext

    private let exclusiveMinValue: Double

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.exclusiveMinValue = value.numeric ?? -.infinity
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let number = input.numeric, number <= exclusiveMinValue {
        throw .belowExclusiveMinimum
      }
    }
  }
}

// MARK: - Strings

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxlength
  struct MaxLength: AssertionKeyword {
    static let name = "maxLength"

    let value: JSONValue
    let context: KeywordContext

    private let maxLength: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxLength = value.integer ?? Int.max
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let string = input.string, string.count > maxLength {
        throw .exceedsMaxLength
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minlength
  struct MinLength: AssertionKeyword {
    static let name = "minLength"

    let value: JSONValue
    let context: KeywordContext

    private let minLength: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minLength = value.integer ?? 0
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let string = input.string, string.count < minLength {
        throw .belowMinLength
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-pattern
  struct Pattern: AssertionKeyword {
    static let name = "pattern"

    let value: JSONValue
    let context: KeywordContext

    nonisolated(unsafe)
    private let regex: Regex<AnyRegexOutput>?

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      if let patternString = value.string {
        self.regex = try? Regex(patternString)
      } else {
        self.regex = nil
      }
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let string = input.string, let regex = regex {
        if string.firstMatch(of: regex) == nil {
          throw .patternMismatch
        }
      }
    }
  }
}

// MARK: - Arrays

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxitems
  struct MaxItems: AssertionKeyword {
    static let name = "maxItems"

    let value: JSONValue
    let context: KeywordContext

    private let maxItems: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxItems = value.integer ?? Int.max
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let array = input.array, array.count > maxItems {
        throw .exceedsMaxItems
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minitems
  struct MinItems: AssertionKeyword {
    static let name = "minItems"

    let value: JSONValue
    let context: KeywordContext

    private let minItems: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minItems = value.integer ?? 0
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if let array = input.array, array.count < minItems {
        throw .belowMinItems
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-uniqueitems
  struct UniqueItems: AssertionKeyword {
    static let name = "uniqueItems"

    let value: JSONValue
    let context: KeywordContext

    private let uniqueItemsRequired: Bool

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.uniqueItemsRequired = value.boolean ?? false
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      if uniqueItemsRequired, let array = input.array {
        let set = Set(array)
        if set.count != array.count {
          throw .itemsNotUnique
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxcontains
  struct MaxContains: AssertionKeyword {
    static let name = "maxContains"

    let value: JSONValue
    let context: KeywordContext

    private let maxContains: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxContains = value.integer ?? Int.max
    }

    func validate(
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
          throw .containsExcessiveMatches
        }
      case .indicies(let indicies):
        if indicies.count > maxContains {
          throw .containsExcessiveMatches
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-mincontains
  struct MinContains: AssertionKeyword {
    static let name = "minContains"

    let value: JSONValue
    let context: KeywordContext

    private let minContains: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minContains = value.integer ?? 1

      if minContains == 0 {
        context.context.minContainsIsZero[context.location.dropLast()] = true
      }
    }

    func validate(
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
          throw .containsInsufficientMatches
        }
      case .indicies(let indicies):
        if indicies.count < minContains {
          throw .containsInsufficientMatches
        }
      }
    }
  }
}

// MARK: - Objects

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxproperties
  struct MaxProperties: AssertionKeyword {
    static let name = "maxProperties"

    let value: JSONValue
    let context: KeywordContext

    private let maxProperties: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxProperties = value.integer ?? Int.max
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let object = input.object else { return }

      if object.count > maxProperties {
        throw .exceedsMaxProperties
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minproperties
  struct MinProperties: AssertionKeyword {
    static let name = "minProperties"

    let value: JSONValue
    let context: KeywordContext

    private let minProperties: Int

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minProperties = value.integer ?? 0
    }

    func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let object = input.object else { return }

      if object.count < minProperties {
        throw ValidationIssue.belowMinProperties
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-required
  struct Required: AssertionKeyword {
    static let name = "required"

    let value: JSONValue
    let context: KeywordContext

    private let requiredKeys: [String]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.requiredKeys = value.array?.compactMap { $0.string } ?? []
    }

    func validate(
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
  struct DependentRequired: AssertionKeyword {
    static let name = "dependentRequired"

    let value: JSONValue
    let context: KeywordContext

    private let dependencies: [String: [String]]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.dependencies =
        value.object?.compactMapValues { $0.array?.compactMap { $0.string } } ?? [:]
    }

    func validate(
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
