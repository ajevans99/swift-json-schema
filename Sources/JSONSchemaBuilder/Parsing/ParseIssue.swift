import JSONSchema

public enum ParseIssue: Error, Equatable, Sendable {
  case typeMismatch(expected: JSONType, actual: JSONValue)
  case numericConversionFailed(value: JSONValue, target: String, reason: String)
  case noEnumCaseMatch(value: JSONValue)
  case missingRequiredProperty(property: String)
  case compactMapValueNil(value: JSONValue)
  case compositionFailure(type: JSONComposition, reason: String, nestedErrors: [ParseIssue])
  case runtimeValidationIssue(ValidationResult)
  case projectionFailure(reason: String)
  case invalidRegularExpression(pattern: String, reason: String)
}

extension ParseIssue: CustomStringConvertible {
  public var description: String {
    switch self {
    case .typeMismatch(let expected, let actual):
      "Type mismatch: the instance of type `\(actual.primitive)` does not match the expected type `\(expected)`."
    case .numericConversionFailed(let value, let target, let reason):
      "Cannot convert JSON number `\(value)` to \(target): \(reason)"
    case .noEnumCaseMatch(let value):
      "The instance `\(value)` does not match any enum case."
    case .missingRequiredProperty(let property):
      "Missing required property `\(property)`."
    case .compactMapValueNil(let value):
      "The instance `\(value)` returned nil when evaluated against compact map."
    case .compositionFailure(let type, let reason, _):
      "Composition (`\(type)`) failure: the instance \(reason)."
    case .runtimeValidationIssue(let error):
      "Runtime validation issue: \(error)"
    case .projectionFailure(let reason):
      "Projection failure: \(reason)"
    case .invalidRegularExpression(let pattern, let reason):
      "Invalid regular expression `\(pattern)`: \(reason)"
    }
  }
}
