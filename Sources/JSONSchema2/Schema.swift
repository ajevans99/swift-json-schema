@_exported import JSONSchema

public struct Schema: ValidatableSchema {
  let schema: any ValidatableSchema
  let location: JSONPointer

  public init(rawSchema: JSONValue, location: JSONPointer = .init()) throws(SchemaIssue) {
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

  init(schema: any ValidatableSchema, location: JSONPointer) {
    self.schema = schema
    self.location = location
  }

  public func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    schema.validate(instance, at: location)
  }
}

struct BooleanSchema: ValidatableSchema {
  let schemaValue: Bool
  let location: JSONPointer

  func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    let validationLocation = ValidationLocation(keywordLocation: self.location, instanceLocation: location)
    return ValidationResult(
      valid: schemaValue,
      location: validationLocation,
      errors: schemaValue ? nil : [ValidationResult(valid: false, location: validationLocation)]
    )
  }

  func asSchema() -> Schema {
    .init(schema: self, location: location)
  }
}

struct ObjectSchema: ValidatableSchema {
  let schemaValue: [String: JSONValue]
  let location: JSONPointer

  var context: Context
  var keywords = [any Keyword]()

  init(schemaValue: [String: JSONValue], location: JSONPointer, context: Context? = nil) {
    self.schemaValue = schemaValue
    self.location = location
    if let context {
      self.context = context
    } else {
      if
        let dialectValue = schemaValue[Keywords.SchemaKeyword.name],
        case let .string(string) = dialectValue,
        let dialect = Dialect(uri: string)
      {
        self.context = Context(dialect: dialect)
      }
      self.context = Context(dialect: .draft2020_12)
    }
    collectKeywords()
  }

  mutating private func collectKeywords() {
    for keywordType in context.dialect.keywords where schemaValue.keys.contains(keywordType.name) {
      let value = schemaValue[keywordType.name]!
      let keyword = keywordType.init(schema: value, location: location)
      keywords.append(keyword)

      if let identifier = keyword as? (any IdentifierKeyword) {
        identifier.processIdentifier(into: &context)
      }
    }
  }

  public func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    var isValid = true
    var errors: [ValidationResult] = []

    let validationLocation = ValidationLocation(keywordLocation: self.location, instanceLocation: location)
    return ValidationResult(
      valid: isValid,
      location: validationLocation,
      errors: isValid ? nil : errors
    )
  }

  func asSchema() -> Schema {
    .init(schema: self, location: location)
  }
}
