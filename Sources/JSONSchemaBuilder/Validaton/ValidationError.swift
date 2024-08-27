import JSONSchema

public protocol ValidationError: Error, CustomStringConvertible, Equatable {}

public enum ValidationIssue: ValidationError {
  /// Indicates a type mismatch during validation.
  /// For instance, when validating against a ``JSONBoolean``, it is expected that the input would be `JSONValue.boolean(Bool)`.
  /// If the actual value is of a different type, such as `JSONValue.string(String)`, this error would be triggered.
  /// - Parameters:
  ///   - expected: The expected JSON type, such as `JSONType.boolean`.
  ///   - actual: The actual JSON value encountered during validation, which differs from the expected type.
  case typeMismatch(expected: JSONType, actual: JSONValue)

  /// Indicates an invalid schema option encountured when validating.
  /// An example is setting the `NumberSchemaOptions.multipleOf` property to a value less than 0.
  /// - Parameters:
  ///  - option: A string representing the invalid option, like `"multipleOf"`.
  ///  - issues: An array of ``ValidationIssue`` emitted from the metaschema that determined this option was invalid.
  case invalidOption(option: String, issues: [ValidationIssue])

  /// The default error used when ``JSONSchemaComponents/compactMap(_:)`` transform returns `nil` value.
  case compactMapTranformNil

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

    public var description: String {
      switch self {
      case .maxProperties(let expected):
        "not more than \(expected) properties"
      case .minProperties(let expected):
        "not less than \(expected) properties"
      case .required(let key):
        "missing a required key '\(key)'"
      case .dependentRequired(let mainProperty, let dependentProperty):
        "missing '\(dependentProperty)' which is required when '\(mainProperty)' is present"
      }
    }
  }

  public var description: String {
    switch self {
    case let .typeMismatch(expected, actual):
      "Expected '\(expected)' type but received '\(actual)'."
    case let .invalidOption(option, issues):
      "Schema option '\(option)' does not meet validation requirements. \(issues.description)."
    case let .number(issue, actual):
      "Value '\(actual)' is \(issue)."
    case let .integer(issue, actual):
      "Value '\(actual)' is \(issue)."
    case let .string(issue, actual):
      "Value '\(actual)' is \(issue)."
    case let .object(issue, actual):
      "Value '\(actual)' is \(issue)."
    case .compactMapTranformNil:
      "The compact map transform function returned nil."
    case let .temporary(string):
      string
    }
  }
}

extension Array where Element: ValidationError {
  var description: String {
    self.map(\.description).joined(separator: ". ")
  }
}

class ValidationErrorBuilder {
  var errors: [ValidationIssue] = []

  func addError(_ error: ValidationIssue?) {
    if let error = error {
      errors.append(error)
    }
  }

  func addErrors(_ newErrors: [ValidationIssue]?) {
    if let newErrors {
      errors.append(contentsOf: newErrors)
    }
  }

  func build<T>(for value: T) -> Validation<T> {
    return errors.isEmpty ? .valid(value) : .invalid(errors)
  }
}
