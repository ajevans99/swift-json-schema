import Foundation

public struct Schema: ValidatableSchema {
  let schema: any ValidatableSchema
  let location: JSONPointer
  let context: Context
  let documentURL: URL

  public init(
    rawSchema: JSONValue,
    location: JSONPointer = .init(),
    context: Context,
    baseURI: URL = URL(fileURLWithPath: #file)
  ) throws(SchemaIssue) {
    self.location = location
    self.context = context

    if self.context.rootRawSchema == nil {
      self.context.rootRawSchema = rawSchema
    }

    let documentURL = baseURI.withoutFragment ?? baseURI
    self.documentURL = documentURL
    if self.context.documentCache[documentURL] == nil {
      self.context.documentCache[documentURL] = SchemaDocument(
        url: documentURL,
        rawSchema: rawSchema
      )
    }

    switch rawSchema {
    case .boolean(let boolValue):
      self.schema = BooleanSchema(
        schemaValue: boolValue,
        location: location,
        context: context
      )
    case .object(let schemaDict):
      self.schema = try ObjectSchema(
        schemaValue: schemaDict,
        location: location,
        context: context,
        baseURI: baseURI,
        documentURL: documentURL
      )
    default:
      throw .schemaShouldBeBooleanOrObject
    }
  }

  public init(
    instance: String,
    dialect: Dialect = .draft2020_12,
    decoder: JSONDecoder = .init(),
    remoteSchemas: [String: JSONValue] = [:],
    formatValidators: [any FormatValidator] = []
  ) throws {
    let value = try decoder.decode(JSONValue.self, from: Data(instance.utf8))
    try self.init(
      rawSchema: value,
      context: .init(
        dialect: dialect,
        remoteSchema: remoteSchemas,
        formatValidators: formatValidators
      )
    )
  }

  init(
    schema: any ValidatableSchema,
    location: JSONPointer,
    context: Context,
    documentURL: URL = URL(fileURLWithPath: #file)
  ) {
    self.schema = schema
    self.location = location
    self.context = context
    self.documentURL = documentURL
  }

  public func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    schema.validate(instance, at: location)
  }

  func validate(
    _ instance: JSONValue,
    at location: JSONPointer,
    annotations: inout AnnotationContainer
  ) -> ValidationResult {
    (schema as? ObjectSchema)?.validate(instance, at: location, annotations: &annotations)
      ?? schema.validate(instance, at: location)
  }
}

package struct BooleanSchema: ValidatableSchema {
  let schemaValue: Bool
  let location: JSONPointer
  let context: Context

  package init(schemaValue: Bool, location: JSONPointer, context: Context) {
    self.schemaValue = schemaValue
    self.location = location
    self.context = context
  }

  package func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    ValidationResult(
      valid: schemaValue,
      keywordLocation: self.location,
      instanceLocation: location,
      errors: schemaValue
        ? []
        : [
          .init(
            keyword: "boolean",
            message: "",
            keywordLocation: self.location,
            instanceLocation: location
          )
        ]
    )
  }

  package func asSchema() -> Schema {
    .init(schema: self, location: location, context: context)
  }
}

package struct ObjectSchema: ValidatableSchema {
  let schemaValue: [String: JSONValue]
  let location: JSONPointer
  let context: Context
  let keywords: [any Keyword]
  let uri: URL?
  let documentURL: URL
  /// Name and base URI for any `$dynamicAnchor` declared on this schema.
  let dynamicAnchorInfo: (name: String, baseURI: URL)?

  package init(
    schemaValue: [String: JSONValue],
    location: JSONPointer,
    context: Context,
    baseURI: URL = URL(fileURLWithPath: #file),
    documentURL: URL = URL(fileURLWithPath: #file)
  ) throws(SchemaIssue) {
    self.schemaValue = schemaValue
    self.location = location
    self.context = context
    self.documentURL = documentURL
    let (processedURI, keywords, dynamicAnchorInfo) = try Self.collectKeywords(
      from: schemaValue,
      location: location,
      context: context,
      baseURI: baseURI
    )
    self.keywords = keywords
    self.uri = processedURI
    self.dynamicAnchorInfo = dynamicAnchorInfo
  }

  private static func collectKeywords(
    from schemaValue: [String: JSONValue],
    location: JSONPointer,
    context: Context,
    baseURI: URL
  ) throws(SchemaIssue) -> (
    processedURI: URL?,
    keywords: [any Keyword],
    dynamicAnchorInfo: (name: String, baseURI: URL)?
  ) {
    var keywords = [any Keyword]()
    var processedURI = baseURI

    var dynamicAnchorInfo: (name: String, baseURI: URL)? = nil

    var didProcessIdentiferKeyword = false

    let previousVocabularies = context.activeVocabularies
    defer { context.activeVocabularies = previousVocabularies }

    // First pass: Process $schema to inherit metaschema vocabularies
    if let schemaKeywordValue = schemaValue[Keywords.SchemaKeyword.name] {
      let keywordLocation = location.appending(.key(Keywords.SchemaKeyword.name))
      let schemaKeyword = Keywords.SchemaKeyword(
        value: schemaKeywordValue,
        context: .init(location: keywordLocation, context: context, uri: processedURI)
      )
      keywords.append(schemaKeyword)

      if let vocabularies = schemaKeyword.resolvedVocabularies() {
        context.activeVocabularies = vocabularies
      }
    }

    // Next, process vocabulary keyword to determine active vocabularies declared on schema
    if let vocabularyValue = schemaValue[Keywords.Vocabulary.name] {
      let keywordLocation = location.appending(.key(Keywords.Vocabulary.name))
      let vocabulary = Keywords.Vocabulary(
        value: vocabularyValue,
        context: .init(location: keywordLocation, context: context, uri: processedURI)
      )
      keywords.append(vocabulary)

      // Validate vocabularies
      try vocabulary.validateVocabularies()

      // Set active vocabularies in the context for sub-schemas
      context.activeVocabularies = vocabulary.getActiveVocabularies()
    }

    // Get keywords filtered by active vocabularies (either from $vocabulary or context)
    let activeVocabs = context.activeVocabularies
    let availableKeywords = context.dialect.keywords(activeVocabularies: activeVocabs)

    // Second pass: Process all other keywords using filtered keyword list
    for keywordType in availableKeywords where schemaValue.keys.contains(keywordType.name) {
      // Skip vocabulary keyword as it's already processed
      if keywordType.name == Keywords.Vocabulary.name
        || keywordType.name == Keywords.SchemaKeyword.name
      {
        continue
      }

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
          didProcessIdentiferKeyword = true
        }
        if let dynamic = identifier as? Keywords.DynamicAnchor, let name = dynamic.value.string {
          dynamicAnchorInfo = (name, processedURI)
        }
      }
    }

    if location.isRoot && !didProcessIdentiferKeyword {
      let documentURL = baseURI.withoutFragment ?? baseURI
      context.identifierRegistry[baseURI] = .init(
        document: documentURL,
        pointer: location
      )
    }

    return (processedURI, keywords, dynamicAnchorInfo)
  }

  package func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult {
    var annotations = AnnotationContainer()
    return validate(instance, at: location, annotations: &annotations)
  }

  package func validate(
    _ instance: JSONValue,
    at location: JSONPointer,
    annotations: inout AnnotationContainer
  ) -> ValidationResult {
    var errors: [ValidationError] = []
    // Push every document-wide `$dynamicAnchor` so this schema inherits the surrounding scope.
    let documentAnchors = context.documentDynamicAnchors[documentURL] ?? [:]
    context.dynamicScopes.append(
      documentAnchors.mapValues {
        (document: documentURL, pointer: $0.pointer, baseURI: $0.baseURI)
      }
    )
    defer {
      _ = context.dynamicScopes.popLast()
    }

    if let dynamicAnchorInfo {
      // A schema-level `$dynamicAnchor` overrides the document entry while this schema validates.
      context.dynamicScopes.append([
        dynamicAnchorInfo.name: (
          document: self.documentURL,
          pointer: self.location,
          baseURI: dynamicAnchorInfo.baseURI
        )
      ])
    }

    defer {
      if dynamicAnchorInfo != nil {
        _ = context.dynamicScopes.popLast()
      }
    }

    for keyword in keywords {
      do throws(ValidationIssue) {
        switch keyword {
        case let reference as any ReferenceKeyword:
          try reference.validate(
            instance,
            at: location,
            using: &annotations,
            with: context,
            baseURI: uri
          )
        case let applicator as any ApplicatorKeyword:
          try applicator.validate(instance, at: location, using: &annotations)
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

  package func asSchema() -> Schema {
    .init(schema: self, location: location, context: context)
  }
}
