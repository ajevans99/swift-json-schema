public protocol ValidationError: Error, CustomStringConvertible, Equatable {}

public indirect enum ValidationIssue: ValidationError {
  /// Indicates that a boolean schema is `false`, and therefore disallows all values.
  case schemaDisallowedAllValues

  /// Indicates a type mismatch during validation.
  /// For instance, when validating against a ``JSONBoolean``, it is expected that the input would be `JSONValue.boolean(Bool)`.
  /// If the actual value is of a different type, such as `JSONValue.string(String)`, this error would be triggered.
  /// - Parameters:
  ///   - expected: The expected JSON type of the schema, such as `JSONType.boolean`.
  ///   - actual: The actual JSON type encountered during validation, which differs from the expected type.
  case typeMismatch(expected: JSONType, actual: JSONPrimative)

  /// Indicates that the instance does not match any of the enum cases defined in the schema.
  /// - Parameters:
  ///   - expected: The array of allowed enum values.
  ///   - actual: The actual value encountered during validation.
  case enumMismatch(expected: [JSONValue], actual: JSONValue)

  /// Indicates that the instance does not match the const value defined in the schema.
  /// - Parameters:
  ///   - expected: The const value defined in the schema.
  ///   - actual: The actual value encountered during validation.
  case constMismatch(expected: JSONValue, actual: JSONValue)

  /// Indicates a validation issue for a number.
  /// - Parameters:
  ///   - issue: The type of number issue.
  ///   - actual: The actual value encountered.
  case number(issue: NumberIssue, actual: Double)

  /// Indicates a validation issue for an integer.
  /// - Parameters:
  ///   - issue: The type of number issue.
  ///   - actual: The actual value encountered.
  case integer(issue: NumberIssue, actual: Int)

  /// Indicates a validation issue for a string.
  /// - Parameters:
  ///  - issue: The type of string issue.
  ///  - actual: The actual value encountered.
  case string(issue: StringIssue, actual: String)

  /// Indicates a validation issue for an object.
  /// - Parameters:
  ///   - issue: The type of object issue.
  ///   - actual: The actual value encountered.
  case object(issue: ObjectIssue, actual: [String: JSONValue])

  /// Indicates a validation issue for an array.
  /// - Parameters:
  ///   - issue: The type of array issue.
  ///   - actual: The actual value encountered.
  case array(issue: ArrayIssue, actual: [JSONValue])

  /// Indicates a composition validation issue.
  /// - Parameters:
  ///   - issue: The type of composition issue.
  ///   - actual: The actual value encountered during validation.
  case composition(issue: CompositionIssue, actual: JSONValue)

  case temporary(String)

  public enum NumberIssue: ValidationError {
    /// Indicates that a value does not meet the `multipleOf` constraint.
    /// - Parameter expected: The expected multiple.
    case multipleOf(expected: Double)

    /// Indicates that a value does not meet the minimum constraint.
    /// - Parameters:
    ///   - isInclusive: Whether the constraint is inclusive.
    ///   - expected: The minimum allowed value.
    case minimum(isInclusive: Bool, expected: Double)

    /// Indicates that a value does not meet the maximum constraint.
    /// - Parameters:
    ///   - isInclusive: Whether the constraint is inclusive.
    ///   - expected: The maximum allowed value.
    case maximum(isInclusive: Bool, expected: Double)

    public var description: String {
      switch self {
      case .multipleOf(let expected):
        "not a multiple of \(expected)"
      case .minimum(let isInclusive, let expected):
        isInclusive ? "not greater than or equal to \(expected)" : "not greater than \(expected)"
      case .maximum(let isInclusive, let expected):
        isInclusive ? "not less than or equal to \(expected)" : "not less than \(expected)"
      }
    }
  }

  public enum StringIssue: ValidationError {
    case minLength(expected: Int)
    case maxLength(expected: Int)
    case pattern(expected: String)

    /// Indicates an invalid regular expression was used.
    case invalidRegularExpression

    public var description: String {
      switch self {
      case .minLength(let expected):
        "not less than \(expected) characters"
      case .maxLength(let expected):
        "not more than \(expected) characters"
      case .pattern(let expected):
        "not does not match pattern '\(expected)'"
      case .invalidRegularExpression:
        "not a valid regular expression"
      }
    }
  }

  public enum ObjectIssue: ValidationError {
    case maxProperties(expected: Int)
    case minProperties(expected: Int)

    /// Indicates an missing required key.
    /// - Parameter key: The missing key.
    case required(key: String)

    case dependentRequired(mainProperty: String, dependentProperty: String)

    // case properties
    // case patternProperties

    case propertyNames(key: String, issues: [ValidationIssue])

    public var description: String {
      switch self {
      case .maxProperties(let expected):
        "not less than \(expected) properties"
      case .minProperties(let expected):
        "not more than \(expected) properties"
      case .required(let key):
        "missing a required key '\(key)'"
      case .dependentRequired(let mainProperty, let dependentProperty):
        "missing '\(dependentProperty)' which is required when '\(mainProperty)' is present"
      case let .propertyNames(key, issues):
        "key '\(key)' does not meet propery name requirements. Violations: \(issues.description)"
      }
    }
  }

  public enum ArrayIssue: ValidationError {
    case maxItems(expected: Int)
    case minItems(expected: Int)
    case uniqueItems(duplicate: JSONValue)
    case maxContains(expected: Int)
    case minContains(expected: Int)

    public var description: String {
      switch self {
      case .maxItems(let expected):
        "not less than \(expected) items in size"
      case .minItems(let expected):
        "not more than \(expected) item in size"
      case .uniqueItems(let duplicate):
        "not unique, '\(duplicate)' occurs more than once"
      case .maxContains(let expected):
        "contains more than \(expected) matching items"
      case .minContains(let expected):
        "contains fewer than \(expected) matching items"
      }
    }
  }

  public indirect enum CompositionIssue: ValidationError {
    /// Indicates that the instance does not match any of the schemas defined in `anyOf`.
    /// - Parameter violations: The list of violations for each schema in `anyOf`.
    case anyOf(violations: [ValidationIssue])

    /// Indicates that the instance does not match all of the schemas defined in `allOf`.
    /// - Parameter violations: The list of violations for each schema in `allOf`.
    case allOf(violations: [ValidationIssue])

    /// Indicates that the instance does not match exactly one of the schemas defined in `oneOf`.
    /// - Parameter violations: The list of violations for each schema in `oneOf`.
    case oneOf(violations: [ValidationIssue])

    /// Indicates that the instance matches the schema defined in `not`.
    case not

    public var description: String {
      switch self {
      case let .anyOf(violations):
        "does not match any of the schemas. Violations: \(violations.description)"
      case let .allOf(violations):
        "does not match all of the schemas. Violations: \(violations.description)"
      case let .oneOf(violations):
        "does not match exactly one of the schemas. Violations: \(violations.description)"
      case .not:
        "matches the schema in 'not'."
      }
    }
  }

  public var description: String {
    switch self {
    case .schemaDisallowedAllValues:
      "Schema disallows all values because schema is set to 'false'."
    case let .typeMismatch(expected, actual):
      "Expected '\(expected)' type but received '\(actual)'."
    case let .enumMismatch(expected, actual):
      "Value '\(actual)' does not match any enum case in '\(expected)'."
    case let .constMismatch(expected, actual):
      "Value '\(actual)' does not match constant '\(expected)'."
    case let .number(issue, actual):
      "Value '\(actual)' is \(issue)."
    case let .integer(issue, actual):
      "Value '\(actual)' is \(issue)."
    case let .string(issue, actual):
      "Value '\(actual)' is \(issue)."
    case let .object(issue, actual):
      "Value '\(actual)' is \(issue)."
    case let .array(issue, actual):
      "Value '\(actual)' is \(issue)"
    case let .temporary(string):
      string
    case let .composition(issue, actual):
      "Value '\(actual)' \(issue)."
    }
  }
}

extension Array where Element: ValidationError {
  var description: String {
    self.map(\.description).joined(separator: "; ")
  }
}
