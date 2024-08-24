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
        "a multiple of \(expected)"
      case .minimum(let isInclusive, let expected):
        isInclusive ? "greater than or equal to \(expected)" : "greater than \(expected)"
      case .maximum(let isInclusive, let expected):
        isInclusive ? "less than or equal to \(expected)" : "less than \(expected)"
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
      "Value '\(actual)' is not \(issue)."
    case let .integer(issue, actual):
      "Value '\(actual)' is not \(issue)."
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
  private var errors: [ValidationIssue] = []

  func addError(_ error: ValidationIssue?) {
    if let error = error {
      errors.append(error)
    }
  }

  func addErrors(_ newErrors: [ValidationIssue]) {
    errors.append(contentsOf: newErrors)
  }

  func build<T>(for value: T) -> Validation<T> {
    return errors.isEmpty ? .valid(value) : .invalid(errors)
  }
}
