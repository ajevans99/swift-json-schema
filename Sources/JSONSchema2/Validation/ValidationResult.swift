public struct ValidationResult: Sendable, Encodable {
  public let valid: Bool
  public let keywordLocation: JSONPointer
  public let instanceLocation: JSONPointer
  public let errors: [ValidationError]?
  public let annotations: [AnyAnnotation]?

  init(
    valid: Bool,
    keywordLocation: JSONPointer,
    instanceLocation: JSONPointer,
    errors: [ValidationError]? = nil,
    annotations: [AnyAnnotation]? = nil
  ) {
    self.valid = valid
    self.keywordLocation = keywordLocation
    self.instanceLocation = instanceLocation
    self.errors = errors
    self.annotations = annotations
  }

  enum CodingKeys: String, CodingKey {
    case valid
    case keywordLocation
    case instanceLocation
    case errors
    case annotations
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(valid, forKey: .valid)
    try container.encode(instanceLocation, forKey: .instanceLocation)
    try container.encode(errors, forKey: .errors)
    try container.encode(annotations?.map { AnyAnnotationWrapper(annotation: $0) }, forKey: .annotations)
  }
}

public struct ValidationError: Sendable, Codable, Equatable {
  public let keyword: String
  public let message: String
  public let keywordLocation: JSONPointer
  public let instanceLocation: JSONPointer
  public let errors: [ValidationError]? // For nested errors

  init(
    keyword: String,
    message: String,
    keywordLocation: JSONPointer,
    instanceLocation: JSONPointer,
    errors: [ValidationError]? = nil
  ) {
    self.keyword = keyword
    self.message = message
    self.keywordLocation = keywordLocation
    self.instanceLocation = instanceLocation
    self.errors = errors
  }
}

public struct AnyAnnotationWrapper: Sendable, Encodable {
  let annotation: AnyAnnotation

  enum CodingKeys: String, CodingKey {
    case keywordLocation
    case absoluteKeywordLocation
    case instanceLocation
    case annotation
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(annotation.schemaLocation, forKey: .keywordLocation)
    try container.encode(annotation.absoluteSchemaLocation, forKey: .absoluteKeywordLocation)
    try container.encode(annotation.instanceLocation, forKey: .instanceLocation)
    try container.encode(annotation.jsonValue, forKey: .annotation)
  }
}
