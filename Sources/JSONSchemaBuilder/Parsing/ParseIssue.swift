import JSONSchema

public enum ParseIssue: Error, Equatable, Sendable {
  case typeMismatch(expected: JSONType, actual: JSONValue)
  case noEnumCaseMatch(value: JSONValue)
  case missingRequiredProperty(property: String)
  case compactMapValueNil(value: JSONValue)
  case compositionFailure(type: JSONComposition, reason: String, nestedErrors: [ParseIssue])
}

extension ParseIssue: CustomStringConvertible {
  public var description: String {
    switch self {
    case .typeMismatch(let expected, let actual):
      "Type mismatch: the instance of type `\(actual.primative)` does not match the expected type `\(expected)`."
    case .noEnumCaseMatch(let value):
      "The instance `\(value)` does not match any enum case."
    case .missingRequiredProperty(let property):
      "Missing required property `\(property)`."
    case .compactMapValueNil(let value):
      "The instance `\(value)` returned nil when evaluated against compact map."
    case .compositionFailure(let type, let reason, _):
      "Composition (`\(type)`) failure: the instance \(reason)."
    }
  }
}
