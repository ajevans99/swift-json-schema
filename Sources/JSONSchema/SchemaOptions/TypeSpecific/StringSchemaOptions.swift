public struct StringSchemaOptions: SchemaOptions, Equatable {
  /// Minimum length of string.The value must be a non-negative number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#length)
  public var minLength: Int?

  /// Maximum length of string.The value must be a non-negative number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#length)
  public var maxLength: Int?

  /// Restrict a string to a particular regular expression.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#regexp)
  public var pattern: String?

  /// Allows for basic semantic identification of certain kinds of string values that are commonly used.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#format)
  public var format: String?

  init(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    format: String? = nil
  ) {
    self.minLength = minLength
    self.maxLength = maxLength
    self.pattern = pattern
    self.format = format
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
