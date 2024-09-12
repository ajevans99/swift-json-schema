protocol AssertionKeyword: Keyword {
  func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue)
}

extension Keywords {
  struct TypeKeyword: AssertionKeyword {
    static let name = "type"

    let schema: JSONValue
    let location: JSONPointer

    private let schemaAllowedPrimitives: [JSONType]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      self.schemaAllowedPrimitives = switch schema {
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

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if !schemaAllowedPrimitives.contains(input.primative) {
        throw .typeMismatch
      }
    }
  }
}

// MARK: - Numbers

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-multipleof
  struct MultipleOf: AssertionKeyword {
    static let name = "multipleOf"

    let schema: JSONValue
    let location: JSONPointer

    private let divisor: Double

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      divisor = schema.numeric ?? 1.0
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let double = input.numeric {
        if double.truncatingRemainder(dividingBy: divisor) != 0 {
          throw .notMultipleOf
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maximum
  struct Maximum: AssertionKeyword {
    static let name = "maximum"

    let schema: JSONValue
    let location: JSONPointer

    private let maxValue: Double

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.maxValue = schema.numeric ?? .infinity
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let number = input.numeric, number > maxValue {
        throw .exceedsMaximum
      }
    }
  }

  struct ExclusiveMaximum: AssertionKeyword {
    static let name = "exclusiveMaximum"

    let schema: JSONValue
    let location: JSONPointer

    private let exclusiveMaxValue: Double

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.exclusiveMaxValue = schema.numeric ?? .infinity
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let number = input.numeric, number >= exclusiveMaxValue {
        throw .exceedsExclusiveMaximum
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minimum
  struct Minimum: AssertionKeyword {
    static let name = "minimum"

    let schema: JSONValue
    let location: JSONPointer

    private let minValue: Double

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.minValue = schema.numeric ?? -.infinity
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let number = input.numeric, number < minValue {
        throw .belowMinimum
      }
    }
  }

  struct ExclusiveMinimum: AssertionKeyword {
    static let name = "exclusiveMinimum"

    let schema: JSONValue
    let location: JSONPointer

    private let exclusiveMinValue: Double

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.exclusiveMinValue = schema.numeric ?? -.infinity
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
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

    let schema: JSONValue
    let location: JSONPointer

    private let maxLength: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.maxLength = schema.integer ?? Int.max
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let string = input.string, string.count > maxLength {
        throw .exceedsMaxLength
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minlength
  struct MinLength: AssertionKeyword {
    static let name = "minLength"

    let schema: JSONValue
    let location: JSONPointer

    private let minLength: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.minLength = schema.integer ?? 0
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let string = input.string, string.count < minLength {
        throw .belowMinLength
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-pattern
  struct Pattern: AssertionKeyword {
    static let name = "pattern"

    let schema: JSONValue
    let location: JSONPointer

    private let regex: Regex<String>?

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      if let patternString = schema.string {
        self.regex = try? Regex(patternString)
      } else {
        self.regex = nil
      }
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let string = input.string, let regex = regex {
        if string.firstMatch(of: regex) == nil {
          throw .patternMismatch
        }
      }
    }

    public static func == (lhs: Pattern, rhs: Pattern) -> Bool {
      lhs.schema == rhs.schema && lhs.location == rhs.location
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(schema)
      hasher.combine(location)
    }
  }
}

// MARK: - Arrays

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-maxitems
  struct MaxItems: AssertionKeyword {
    static let name = "maxItems"

    let schema: JSONValue
    let location: JSONPointer

    private let maxItems: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.maxItems = schema.integer ?? Int.max
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let array = input.array, array.count > maxItems {
        throw .exceedsMaxItems
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minitems
  struct MinItems: AssertionKeyword {
    static let name = "minItems"

    let schema: JSONValue
    let location: JSONPointer

    private let minItems: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.minItems = schema.integer ?? 0
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      if let array = input.array, array.count < minItems {
        throw .belowMinItems
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-uniqueitems
  struct UniqueItems: AssertionKeyword {
    static let name = "uniqueItems"

    let schema: JSONValue
    let location: JSONPointer

    private let uniqueItemsRequired: Bool

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.uniqueItemsRequired = schema.boolean ?? false
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
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

    let schema: JSONValue
    let location: JSONPointer

    private let maxContains: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.maxContains = schema.integer ?? Int.max
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      guard let array = input.array else { return }

      guard let containsAnnotation = annotations[Keywords.Contains.self] else { return }

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

    let schema: JSONValue
    let location: JSONPointer

    private let minContains: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.minContains = schema.integer ?? 1
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      guard let array = input.array else { return }

      guard let containsAnnotation = annotations[Keywords.Contains.self] else { return }

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

    let schema: JSONValue
    let location: JSONPointer

    private let maxProperties: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.maxProperties = schema.integer ?? Int.max
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      guard let object = input.object else { return }

      if object.count > maxProperties {
        throw .exceedsMaxProperties
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-minproperties
  struct MinProperties: AssertionKeyword {
    static let name = "minProperties"

    let schema: JSONValue
    let location: JSONPointer

    private let minProperties: Int

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.minProperties = schema.integer ?? 0
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      guard let object = input.object else { return }

      if object.count < minProperties {
        throw ValidationIssue.belowMinProperties
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-required
  struct Required: AssertionKeyword {
    static let name = "required"

    let schema: JSONValue
    let location: JSONPointer

    private let requiredKeys: [String]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.requiredKeys = schema.array?.compactMap { $0.string } ?? []
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      guard let object = input.object else { return }

      for key in requiredKeys {
        if !object.keys.contains(key) {
          throw ValidationIssue.missingRequiredProperty(key: key)
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-validation#name-dependentrequired
  struct DependentRequired: AssertionKeyword {
    static let name = "dependentRequired"

    let schema: JSONValue
    let location: JSONPointer

    private let dependencies: [String: [String]]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.dependencies = schema.object?.compactMapValues { $0.array?.compactMap { $0.string } } ?? [:]
    }

    func validate(_ input: JSONValue, at location: ValidationLocation, using annotations: AnnotationContainer) throws(ValidationIssue) {
      guard let object = input.object else { return }

      for (key, dependentKeys) in dependencies {
        if object.keys.contains(key) {
          for requiredKey in dependentKeys {
            if !object.keys.contains(requiredKey) {
              throw ValidationIssue.missingDependentProperty(key: requiredKey, dependentOn: key)
            }
          }
        }
      }
    }
  }
}
