import JSONSchema

public enum ParseIssue: Error, Equatable, Sendable {
  case typeMismatch(expected: JSONType, actual: JSONValue)
  case noEnumCaseMatch(value: JSONValue)
  case missingRequiredProperty(property: String)
  case compactMapValueNil(value: JSONValue)
  case compositionFailure(type: JSONComposition, reason: String, nestedErrors: [ParseIssue])
}
