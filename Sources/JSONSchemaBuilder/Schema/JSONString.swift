import JSONSchema

/// A JSON string schema component for use in ``JSONSchemaBuilder``.
public struct JSONString: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()
  var options: StringSchemaOptions = .options()

  public var definition: Schema { .string(annotations, options) }

  public init() {}
}

extension JSONString {
  /// Adds a minimum length constraint to the schema.
  /// - Parameter length: The minimum length that the string must be greater than or equal to.
  /// - Returns: A new `JSONString` with the minimum length constraint set.
  public func minLength(_ length: Int) -> Self {
    var copy = self
    copy.options.minLength = length
    return copy
  }

  /// Adds a maximum length constraint to the schema.
  /// - Parameter length: The maximum length that the string must be less than or equal to.
  /// - Returns: A new `JSONString` with the maximum length constraint set.
  public func maxLength(_ length: Int) -> Self {
    var copy = self
    copy.options.maxLength = length
    return copy
  }

  /// Adds a pattern constraint to the schema.
  /// - Parameter pattern: The regular expression pattern that the string must match.
  /// - Returns: A new `JSONString` with the pattern constraint set.
  public func pattern(_ pattern: String) -> Self {
    var copy = self
    copy.options.pattern = pattern
    return copy
  }

  /// Adds a format constraint to the schema.
  /// - Parameter format: The format that the string must adhere to.
  /// - Returns: A new `JSONString` with the format constraint set.
  public func format(_ format: String) -> Self {
    var copy = self
    copy.options.format = format
    return copy
  }
}
