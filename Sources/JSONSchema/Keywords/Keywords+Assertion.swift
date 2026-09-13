package protocol AssertionKeyword: Keyword {
  func validate(
    _ input: JSONValue,
    at location: JSONPointer,
    using annotations: AnnotationContainer
  ) throws(ValidationIssue)
}

protocol ValidationKeyword: AssertionKeyword {}

extension ValidationKeyword {
  package static var vocabulary: String {
    "https://json-schema.org/draft/2020-12/vocab/validation"
  }

  func countBound() throws(ValidationIssue) -> JSONNumberLiteral {
    guard let bound = value.numberLiteral, bound.isInteger, bound >= JSONNumberLiteral(0) else {
      throw .numericValidationFailure(reason: "'\(Self.name)' must be a nonnegative integer")
    }
    return bound
  }
}

extension JSONNumberLiteral {
  /// Narrows a validated count or length bound to `Int` so a failure can report it.
  ///
  /// Bound comparisons use the full-precision literal, so narrowing here only affects how an
  /// already-determined failure is described. A bound outside `Int`'s range is reported as a
  /// numeric validation failure rather than clamped to a misleading value.
  func intBound(for keyword: String) throws(ValidationIssue) -> Int {
    guard let bound = try? integerValue() else {
      throw .numericValidationFailure(
        reason: "'\(keyword)' bound \(self) is outside the representable range"
      )
    }
    return bound
  }
}

protocol FormatKeyword: AssertionKeyword {}

extension FormatKeyword {
  package static var vocabulary: String {
    "https://json-schema.org/draft/2020-12/vocab/format-annotation"
  }
}

extension Keywords {
  package struct TypeKeyword: ValidationKeyword {
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
          || (allowedType == .integer && input.isMathematicalInteger)
      }
      if !isValid {
        throw ValidationIssue.typeMismatch(expected: allowedPrimitives, actual: instanceType)
      }
    }
  }

  package struct Enum: ValidationKeyword {
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

  package struct Constant: ValidationKeyword {
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
  package struct MultipleOf: ValidationKeyword {
    package static let name = "multipleOf"

    package let value: JSONValue
    package let context: KeywordContext

    private let divisor: JSONNumberLiteral?

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      divisor = value.numberLiteral
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let divisor, divisor > JSONNumberLiteral(0) else {
        throw .numericValidationFailure(reason: "'multipleOf' must be a positive number")
      }
      guard let number = input.numberLiteral else { return }
      let isMultiple: Bool
      do {
        isMultiple = try number.isMultiple(of: divisor)
      } catch {
        throw .numericValidationFailure(reason: "Cannot evaluate 'multipleOf': \(error)")
      }
      if !isMultiple {
        throw .notMultipleOf(number: number, multiple: divisor)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maximum
  package struct Maximum: ValidationKeyword {
    package static let name = "maximum"

    package let value: JSONValue
    package let context: KeywordContext

    private let maxValue: JSONNumberLiteral?

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.maxValue = value.numberLiteral
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let maxValue else {
        throw .numericValidationFailure(reason: "'maximum' must be a number")
      }
      if let number = input.numberLiteral, number > maxValue {
        throw ValidationIssue.exceedsMaximum(number: number, maximum: maxValue)
      }
    }
  }

  package struct ExclusiveMaximum: ValidationKeyword {
    package static let name = "exclusiveMaximum"

    package let value: JSONValue
    package let context: KeywordContext

    private let exclusiveMaxValue: JSONNumberLiteral?

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.exclusiveMaxValue = value.numberLiteral
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let exclusiveMaxValue else {
        throw .numericValidationFailure(reason: "'exclusiveMaximum' must be a number")
      }
      if let number = input.numberLiteral, number >= exclusiveMaxValue {
        throw ValidationIssue.exceedsExclusiveMaximum(number: number, maximum: exclusiveMaxValue)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minimum
  package struct Minimum: ValidationKeyword {
    package static let name = "minimum"

    package let value: JSONValue
    package let context: KeywordContext

    private let minValue: JSONNumberLiteral?

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.minValue = value.numberLiteral
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let minValue else {
        throw .numericValidationFailure(reason: "'minimum' must be a number")
      }
      if let number = input.numberLiteral, number < minValue {
        throw ValidationIssue.belowMinimum(number: number, minimum: minValue)
      }
    }
  }

  package struct ExclusiveMinimum: ValidationKeyword {
    package static let name = "exclusiveMinimum"

    package let value: JSONValue
    package let context: KeywordContext

    private let exclusiveMinValue: JSONNumberLiteral?

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.exclusiveMinValue = value.numberLiteral
    }

    package func validate(
      _ input: JSONValue,
      at location: JSONPointer,
      using annotations: AnnotationContainer
    ) throws(ValidationIssue) {
      guard let exclusiveMinValue else {
        throw .numericValidationFailure(reason: "'exclusiveMinimum' must be a number")
      }
      if let number = input.numberLiteral, number <= exclusiveMinValue {
        throw ValidationIssue.belowExclusiveMinimum(number: number, minimum: exclusiveMinValue)
      }
    }
  }
}

// MARK: - Strings

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxlength
  package struct MaxLength: ValidationKeyword {
    package static let name = "maxLength"

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
      let maxLength = try countBound()
      if let string = input.string, JSONNumberLiteral(string.count) > maxLength {
        throw ValidationIssue.exceedsMaxLength(
          string: string,
          maxLength: try maxLength.intBound(for: Self.name)
        )
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minlength
  package struct MinLength: ValidationKeyword {
    package static let name = "minLength"

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
      let minLength = try countBound()
      if let string = input.string, JSONNumberLiteral(string.count) < minLength {
        throw ValidationIssue.belowMinLength(
          string: string,
          minLength: try minLength.intBound(for: Self.name)
        )
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-pattern
  package struct Pattern: ValidationKeyword {
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

  package struct Format: FormatKeyword {
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
  package struct MaxItems: ValidationKeyword {
    package static let name = "maxItems"

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
      let maxItems = try countBound()
      if let array = input.array, JSONNumberLiteral(array.count) > maxItems {
        throw ValidationIssue.exceedsMaxItems(
          count: array.count,
          maxItems: try maxItems.intBound(for: Self.name)
        )
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minitems
  package struct MinItems: ValidationKeyword {
    package static let name = "minItems"

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
      let minItems = try countBound()
      if let array = input.array, JSONNumberLiteral(array.count) < minItems {
        throw ValidationIssue.belowMinItems(
          count: array.count,
          minItems: try minItems.intBound(for: Self.name)
        )
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-uniqueitems
  package struct UniqueItems: ValidationKeyword {
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
  package struct MaxContains: ValidationKeyword {
    package static let name = "maxContains"

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
      guard let array = input.array else { return }

      guard let containsAnnotation = annotations.annotation(for: Contains.self, at: location) else {
        return
      }

      let maxContains = try countBound()
      switch containsAnnotation.value {
      case .everyIndex:
        if JSONNumberLiteral(array.count) > maxContains {
          throw ValidationIssue.containsExcessiveMatches(
            count: array.count,
            maxAllowed: try maxContains.intBound(for: Self.name)
          )
        }
      case .indicies(let indicies):
        if JSONNumberLiteral(indicies.count) > maxContains {
          throw ValidationIssue.containsExcessiveMatches(
            count: indicies.count,
            maxAllowed: try maxContains.intBound(for: Self.name)
          )
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-mincontains
  package struct MinContains: ValidationKeyword {
    package static let name = "minContains"

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
      guard let array = input.array else { return }

      guard let containsAnnotation = annotations.annotation(for: Contains.self, at: location) else {
        return
      }

      let minContains = try countBound()
      switch containsAnnotation.value {
      case .everyIndex:
        if JSONNumberLiteral(array.count) < minContains {
          throw ValidationIssue.containsInsufficientMatches(
            count: array.count,
            required: try minContains.intBound(for: Self.name)
          )
        }
      case .indicies(let indicies):
        if JSONNumberLiteral(indicies.count) < minContains {
          throw ValidationIssue.containsInsufficientMatches(
            count: indicies.count,
            required: try minContains.intBound(for: Self.name)
          )
        }
      }
    }
  }
}

// MARK: - Objects

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxproperties
  package struct MaxProperties: ValidationKeyword {
    package static let name = "maxProperties"

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
      guard let object = input.object else { return }

      let maxProperties = try countBound()
      if JSONNumberLiteral(object.count) > maxProperties {
        throw ValidationIssue.exceedsMaxProperties(
          count: object.count,
          maxProperties: try maxProperties.intBound(for: Self.name)
        )
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minproperties
  package struct MinProperties: ValidationKeyword {
    package static let name = "minProperties"

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
      guard let object = input.object else { return }

      let minProperties = try countBound()
      if JSONNumberLiteral(object.count) < minProperties {
        throw ValidationIssue.belowMinProperties(
          count: object.count,
          minProperties: try minProperties.intBound(for: Self.name)
        )
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-required
  package struct Required: ValidationKeyword {
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
  package struct DependentRequired: ValidationKeyword {
    package static let name = "dependentRequired"

    package let value: JSONValue
    package let context: KeywordContext

    private let dependencies: [String: [String]]

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.dependencies = Dictionary(
        uniqueKeysWithValues: value.object?
          .compactMap { (key, value) -> (String, [String])? in
            guard let array = value.array?.compactMap({ $0.string }) else { return nil }
            return (key, array)
          } ?? []
      )
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
