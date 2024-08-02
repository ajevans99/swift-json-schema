import JSONSchema

public enum SchemaValidationError: Error {
  case typeMismatch(expected: JSONType, found: JSONValue)
  case objectError(ObjectValidationError)
}

extension SchemaValidationError {
  public enum ObjectValidationError: Sendable {
    case duplicateKeysInRequiredProperty([String])
    case missingRequiredProperty(String)
    case additionalPropertiesFound([String])
  }
}
