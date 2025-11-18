public struct ValidationResult: Sendable, Encodable, Equatable {
  public let isValid: Bool
  public let keywordLocation: JSONPointer
  public let absoluteKeywordLocation: String?
  public let instanceLocation: JSONPointer
  public let errors: [ValidationError]?
  public let annotations: [AnyAnnotation]?

  init(
    valid: Bool,
    keywordLocation: JSONPointer,
    absoluteKeywordLocation: String? = nil,
    instanceLocation: JSONPointer,
    errors: [ValidationError]? = nil,
    annotations: [AnyAnnotation]? = nil
  ) {
    self.isValid = valid
    self.keywordLocation = keywordLocation
    self.absoluteKeywordLocation = absoluteKeywordLocation
    self.instanceLocation = instanceLocation
    self.errors = errors
    self.annotations = annotations
  }

  enum CodingKeys: String, CodingKey {
    case isValid = "valid"
    case keywordLocation
    case absoluteKeywordLocation
    case instanceLocation
    case errors
    case annotations
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(isValid, forKey: .isValid)
    try container.encode(keywordLocation, forKey: .keywordLocation)
    try container.encodeIfPresent(absoluteKeywordLocation, forKey: .absoluteKeywordLocation)
    try container.encode(instanceLocation, forKey: .instanceLocation)
    try container.encodeIfPresent(errors, forKey: .errors)
    try container.encodeIfPresent(
      annotations?.map { AnyAnnotationWrapper(annotation: $0) },
      forKey: .annotations
    )
  }

  public static func == (lhs: ValidationResult, rhs: ValidationResult) -> Bool {
    lhs.isValid == rhs.isValid
      && lhs.keywordLocation == rhs.keywordLocation
      && lhs.absoluteKeywordLocation == rhs.absoluteKeywordLocation
      && lhs.instanceLocation == rhs.instanceLocation
      && lhs.errors == rhs.errors
  }
}

public struct ValidationError: Sendable, Codable, Equatable {
  public let keyword: String
  public let message: String
  public let keywordLocation: JSONPointer
  public let absoluteKeywordLocation: String?
  public let instanceLocation: JSONPointer
  public let errors: [ValidationError]?  // For nested errors

  init(
    keyword: String,
    message: String,
    keywordLocation: JSONPointer,
    absoluteKeywordLocation: String? = nil,
    instanceLocation: JSONPointer,
    errors: [ValidationError]? = nil
  ) {
    self.keyword = keyword
    self.message = message
    self.keywordLocation = keywordLocation
    self.absoluteKeywordLocation = absoluteKeywordLocation
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
    try container.encodeIfPresent(
      annotation.absoluteSchemaLocation,
      forKey: .absoluteKeywordLocation
    )
    try container.encode(annotation.instanceLocation, forKey: .instanceLocation)
    try container.encode(annotation.jsonValue, forKey: .annotation)
  }
}

extension ValidationError {
  /// Returns a copy of the error whose `keywordLocation` is rewritten so it appears
  /// underneath a referencing keyword (for example `$ref`).
  ///
  /// - Parameters:
  ///   - prefix: The pointer belonging to the referencing keyword that should prefix the error.
  ///   - base: The pointer at which the referenced schema begins; segments before this base are removed.
  /// - Returns: A cloned `ValidationError` whose `keywordLocation` (and any nested child errors)
  ///   are rebased beneath the referencing keyword while preserving absolute locations.
  func prefixedKeywordLocation(
    with prefix: JSONPointer,
    removingBase base: JSONPointer
  ) -> ValidationError {
    let relativePointer = keywordLocation.relative(toBase: base)
    let newKeywordLocation = prefix.appending(pointer: relativePointer)
    let prefixedChildren = errors?
      .map {
        $0.prefixedKeywordLocation(with: prefix, removingBase: base)
      }

    return ValidationError(
      keyword: keyword,
      message: message,
      keywordLocation: newKeywordLocation,
      absoluteKeywordLocation: absoluteKeywordLocation,
      instanceLocation: instanceLocation,
      errors: prefixedChildren
    )
  }
}
