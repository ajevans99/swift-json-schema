import JSONSchema

extension JSONSchemaComponent {
  /// Specifies the encoding used to represent non-JSON data.
  /// - Parameter value: The content encoding (e.g. "base64").
  /// - Returns: A new instance with the `contentEncoding` keyword set.
  public func contentEncoding(_ value: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.ContentEncoding.name] = .string(value)
    return copy
  }

  /// Specifies the media type of the decoded content.
  /// - Parameter value: The media type (e.g. "image/png").
  /// - Returns: A new instance with the `contentMediaType` keyword set.
  public func contentMediaType(_ value: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.ContentMediaType.name] = .string(value)
    return copy
  }
}
