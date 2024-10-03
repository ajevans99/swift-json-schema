@_exported import JSONSchema
import Foundation

public struct Schema: ValidatableSchema {
  let schema: any ValidatableSchema
  let location: JSONPointer
  let context: Context

  public init(
    rawSchema: JSONValue,
    location: JSONPointer = .init(),
    context: Context,
    baseURI: URL? = nil
  ) throws(SchemaIssue) {
    self.location = location
    self.context = context

    if self.context.rootRawSchema == nil {
      self.context.rootRawSchema = rawSchema
    }

    switch rawSchema {
    case .boolean(let boolValue):
      self.schema = BooleanSchema(
        schemaValue: boolValue,
        location: location,
        context: context
      )
    case .object(let schemaDict):
      self.schema = ObjectSchema(
        schemaValue: schemaDict,
        location: location,
        context: context,
        baseURI: baseURI
      )
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
    return ValidationResult(
      valid: schemaValue,
      keywordLocation: self.location,
      instanceLocation: location,
      errors: schemaValue ? [] : [.init(keyword: "boolean", message: "", keywordLocation: self.location, instanceLocation: location)]
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
  let keywords: [any Keyword]
  let uri: URL?

  init(
    schemaValue: [String: JSONValue],
    location: JSONPointer,
    context: Context,
    baseURI: URL? = nil
  ) {
    self.schemaValue = schemaValue
    self.location = location
    self.context = context
    let (processedURI, keywords) = Self.collectKeywords(
      from: schemaValue,
      location: location,
      context: context,
      baseURI: baseURI
    )
    self.keywords = keywords
    self.uri = processedURI
  }

  static func collectKeywords(
    from schemaValue: [String: JSONValue],
    location: JSONPointer,
    context: Context,
    baseURI: URL?
  ) -> (processedURI: URL?, keywords: [any Keyword]) {
    var keywords = [any Keyword]()
    var processedURI = baseURI

    for keywordType in context.dialect.keywords where schemaValue.keys.contains(keywordType.name) {
      let value = schemaValue[keywordType.name]!
      let keywordLocation = location.appending(.key(keywordType.name))
      let keyword = keywordType.init(
        value: value,
        context: .init(location: keywordLocation, context: context, uri: processedURI)
      )
      keywords.append(keyword)

      if let identifier = keyword as? (any IdentifierKeyword) {
        identifier.processIdentifier()

        if let id = identifier as? Keywords.Identifier {
          processedURI = id.processSubschema(baseURI: baseURI)
        }
      }
    }

    return (processedURI, keywords)
  }

  public func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    var errors: [ValidationError] = []

    var annotations = AnnotationContainer()

    for keyword in keywords {
      do throws(ValidationIssue) {
        switch keyword {
        case let reference as any ReferenceKeyword:
          try reference.validate(instance, at: location, using: &annotations, with: context, baseURI: uri)
        case let applicator as any ApplicatorKeyword:
          try applicator.validate(instance, at: location, using: &annotations, with: context)
        case let assertion as any AssertionKeyword:
          try assertion.validate(instance, at: location, using: annotations)
        default:
          continue
        }
      } catch {
        let keywordName = type(of: keyword).name
        let validationError = error.makeValidationError(
          keyword: keywordName,
          keywordLocation: self.location.appending(.key(keywordName)),
          instanceLocation: location
        )
        errors.append(validationError)
      }
    }

    let collectedAnnotations = annotations.allAnnotations()

    return ValidationResult(
      valid: errors.isEmpty,
      keywordLocation: self.location,
      instanceLocation: location,
      errors: errors.isEmpty ? nil : errors,
      annotations: collectedAnnotations.isEmpty ? nil : collectedAnnotations
    )
  }

  func asSchema() -> Schema {
    .init(schema: self, location: location, context: context)
  }
}
