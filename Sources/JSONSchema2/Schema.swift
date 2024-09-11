@_exported import JSONSchema

public struct Schema: ValidatableSchema {
  let schema: ValidatableSchema
  let location: ValidationLocation

  init(rawSchema: JSONValue, location: ValidationLocation = .init()) throws(SchemaIssue) {
    self.location = location

    switch rawSchema {
    case .boolean(let boolValue):
      self.schema = BooleanSchema(schemaValue: boolValue, location: location)
    case .object(let schemaDict):
      self.schema = ObjectSchema(schemaValue: schemaDict, location: location)
    default:
      throw .schemaShouldBeBooleanOrObject
    }
  }

  public func validate(_ instance: JSONValue) -> ValidationResult {
    return schema.validate(instance)
  }
}

struct BooleanSchema: ValidatableSchema {
  let schemaValue: Bool
  let location: ValidationLocation

  func validate(_ instance: JSONValue) -> ValidationResult {
    return ValidationResult(
      valid: schemaValue,
      location: location,
      errors: schemaValue ? nil : [ValidationResult(valid: false, location: location)]
    )
  }
}

struct ObjectSchema: ValidatableSchema {
  let schemaValue: [String: JSONValue]
  let location: ValidationLocation

  var keywords = [any Keyword]()

  init(schemaValue: [String: JSONValue], location: ValidationLocation) {
    self.schemaValue = schemaValue
    self.location = location
    self.keywords = collectKeywords()
  }

  func collectKeywords() -> [any Keyword] {
    []
  }

  func validate(_ instance: JSONValue) -> ValidationResult {
    var isValid = true
    var errors: [ValidationResult] = []



    return ValidationResult(
      valid: isValid,
      location: location,
      errors: isValid ? nil : errors
    )
  }
}
