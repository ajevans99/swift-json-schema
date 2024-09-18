@_exported import JSONSchema

public struct Schema: ValidatableSchema {
  let schema: any ValidatableSchema
  let location: JSONPointer
  let context: Context

  public init(rawSchema: JSONValue, location: JSONPointer = .init(), context: Context) throws(SchemaIssue) {
    self.location = location
    self.context = context
    if self.context.rootRawSchema == nil {
      self.context.rootRawSchema = rawSchema
    }
    switch rawSchema {
    case .boolean(let boolValue):
      self.schema = BooleanSchema(schemaValue: boolValue, location: location, context: context)
    case .object(let schemaDict):
      self.schema = ObjectSchema(schemaValue: schemaDict, location: location, context: context)
    default:
      throw .schemaShouldBeBooleanOrObject
    }
  }

  init(schema: any ValidatableSchema, location: JSONPointer, context: Context) {
    self.schema = schema
    self.location = location
    self.context = context
  }

  public func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    schema.validate(instance, at: location)
  }
}

struct BooleanSchema: ValidatableSchema {
  let schemaValue: Bool
  let location: JSONPointer
  let context: Context

  func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    let validationLocation = ValidationLocation(keywordLocation: self.location, instanceLocation: location)
    return ValidationResult(
      valid: schemaValue,
      location: validationLocation,
      errors: schemaValue ? nil : [ValidationResult(valid: false, location: validationLocation)]
    )
  }

  func asSchema() -> Schema {
    .init(schema: self, location: location, context: context)
  }
}

struct ObjectSchema: ValidatableSchema {
  let schemaValue: [String: JSONValue]
  let location: JSONPointer

  let context: Context
  var keywords = [any Keyword]()

  init(schemaValue: [String: JSONValue], location: JSONPointer, context: Context) {
    self.schemaValue = schemaValue
    self.location = location
    self.context = context
    collectKeywords()
  }

  mutating private func collectKeywords() {
    for keywordType in context.dialect.keywords where schemaValue.keys.contains(keywordType.name) {
      let value = schemaValue[keywordType.name]!
      let keyword = keywordType.init(schema: value, location: location, context: context)
      keywords.append(keyword)

      if let identifier = keyword as? (any IdentifierKeyword) {
        identifier.processIdentifier(into: context)
      }
    }
  }

  public func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    var errors: [ValidationResult] = []

    var annotations = AnnotationContainer()

    for keyword in keywords {
      do throws(ValidationIssue) {
        switch keyword {
        case let reference as any ReferenceKeyword:
          try reference.validate(instance, at: location, using: &annotations, with: context)
        case let applicator as any ApplicatorKeyword:
          try applicator.validate(instance, at: location, using: &annotations, with: context)
        case let assertion as any AssertionKeyword:
          try assertion.validate(instance, at: location, using: annotations)
        default:
          continue
        }
      } catch {
        errors.append(.init(valid: false, location: .init(keywordLocation: location, instanceLocation: location), error: error))
      }
    }

    let validationLocation = ValidationLocation(keywordLocation: self.location, instanceLocation: location)
    return ValidationResult(
      valid: errors.isEmpty,
      location: validationLocation,
      errors: errors.isEmpty ? nil : errors
    )
  }

  func asSchema() -> Schema {
    .init(schema: self, location: location, context: context)
  }
}
