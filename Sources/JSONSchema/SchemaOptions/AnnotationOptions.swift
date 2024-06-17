/// Part of schema that isn't strictly used for validation, but are used to describe parts of a schema
/// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/annotations#annotations)
public struct AnnotationOptions: Codable, Equatable, Sendable {
  /// Short title about the purpose of the data described by the schema.
  public let title: String?
  
  /// Longer description about the purpose of the data described by the schema.
  public let description: String?
  
  /// Non-validation tools such as documentation generators or form generators may use this value to give hints to users about how to use a value.
  /// However, default is typically used to express that if a value is missing, then the value is semantically the same as if the value was present with the default value.
  public let `default`: JSONValue?

  /// An array of examples that validate against the schema.
  public let examples: [JSONValue]?

  /// Indicates that a value should not be modified.
  public let readOnly: Bool?
  
  /// Indicates that a value may be set, but will remain hidden.
  public let writeOnly: Bool?

  /// Indicates that the instance value the keyword applies to should not be used and may be removed in the future.
  public let deprecated: Bool?

  /// Strictly intended for adding comments to a schema.
  public let comment: String?

  enum CodingKeys: String, CodingKey {
    case title, description, `default`, examples, readOnly, writeOnly, deprecated
    case comment = "$comment"
  }

  init(
    title: String? = nil,
    description: String? = nil,
    `default`: (JSONValue)? = nil,
    examples: [JSONValue]? = nil,
    readOnly: Bool? = nil,
    writeOnly: Bool? = nil,
    deprecated: Bool? = nil,
    comment: String? = nil
  ) {
    self.title = title
    self.description = description
    self.`default` = `default`
    self.examples = examples
    self.readOnly = readOnly
    self.writeOnly = writeOnly
    self.deprecated = deprecated
    self.comment = comment
  }

  public static func annotations(
    title: String? = nil,
    description: String? = nil,
    `default`: (JSONValue)? = nil,
    examples: [JSONValue]? = nil,
    readOnly: Bool? = nil,
    writeOnly: Bool? = nil,
    deprecated: Bool? = nil,
    comment: String? = nil
  ) -> Self {
    self.init(
      title: title,
      description: description,
      default: `default`,
      examples: examples,
      readOnly: readOnly,
      writeOnly: writeOnly,
      deprecated: deprecated,
      comment: comment
    )
  }
}
