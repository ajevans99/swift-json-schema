import JSONSchema

extension JSONSchemaComponent {
  /// Sets the title of the schema.
  /// - Parameter value: A string representing the title of the schema.
  /// - Returns: A new instance of the schema with the title set.
  public func title(_ value: String?) -> Self {
    var copy = self
    copy.annotations.title = value
    return copy
  }

  /// Sets the description of the schema.
  /// - Parameter value: A string describing the schema.
  /// - Returns: A new instance of the schema with the description set.
  public func description(_ value: String?) -> Self {
    var copy = self
    copy.annotations.description = value
    return copy
  }

  public func `default`(_ value: JSONValue?) -> Self {
    var copy = self
    copy.annotations.default = value
    return copy
  }

  /// Sets the default value of the schema.
  /// - Parameter value: A closure that returns a JSON value representing the default value.
  /// - Returns: A new instance of the schema with the default value set.
  public func `default`(@JSONValueBuilder _ value: () -> JSONValueRepresentable) -> Self {
    self.default(value().value)
  }

  public func examples(_ values: JSONValue?) -> Self {
    var copy = self
    copy.annotations.examples = values
    return copy
  }

  /// Sets the examples of the schema.
  /// - Parameter examples: A closure that returns a JSON value representing the examples.
  /// - Returns: A new instance of the schema with the examples set.
  public func examples(@JSONValueBuilder _ examples: () -> JSONValueRepresentable) -> Self {
    self.examples(examples().value)
  }

  /// Sets the readOnly flag of the schema.
  /// - Parameter value: A boolean value indicating whether the schema is read-only.
  /// - Returns: A new instance of the schema with the `readOnly` flag set.
  public func readOnly(_ value: Bool?) -> Self {
    var copy = self
    copy.annotations.readOnly = value
    return copy
  }

  /// Sets the writeOnly flag of the schema.
  /// - Parameter value: A boolean value indicating whether the schema is write-only.
  /// - Returns: A new instance of the schema with the `writeOnly` flag set.
  public func writeOnly(_ value: Bool?) -> Self {
    var copy = self
    copy.annotations.writeOnly = value
    return copy
  }

  /// Sets the deprecated flag of the schema.
  /// - Parameter value: A boolean value indicating whether the schema is deprecated.
  /// - Returns: A new instance of the schema with the `deprecated` flag set.
  public func deprecated(_ value: Bool?) -> Self {
    var copy = self
    copy.annotations.deprecated = value
    return copy
  }

  /// Sets the comment of the schema.
  /// - Parameter value: A string representing a comment for the schema.
  /// - Returns: A new instance of the schema with the comment set.
  public func comment(_ value: String?) -> Self {
    var copy = self
    copy.annotations.comment = value
    return copy
  }
}
