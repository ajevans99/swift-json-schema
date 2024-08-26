public struct StringSchemaOptions: SchemaOptions, Equatable {
  /// Minimum length of string.The value must be a non-negative number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#length)
  public var minLength: JSONValue?

  /// Maximum length of string.The value must be a non-negative number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#length)
  public var maxLength: JSONValue?

  /// Restrict a string to a particular regular expression.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#regexp)
  public var pattern: JSONValue?

  /// Allows for basic semantic identification of certain kinds of string values that are commonly used.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#format)
  public var format: JSONValue?

  init(minLength: Int? = nil, maxLength: Int? = nil, pattern: String? = nil, format: String? = nil)
  {
    self.minLength = minLength.map { JSONValue($0) }
    self.maxLength = maxLength.map { JSONValue($0) }
    self.pattern = pattern.map { JSONValue($0) }
    self.format = format.map { JSONValue($0) }
  }

  public static func options(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    format: String? = nil
  ) -> Self {
    self.init(minLength: minLength, maxLength: maxLength, pattern: pattern, format: format)
  }
}

