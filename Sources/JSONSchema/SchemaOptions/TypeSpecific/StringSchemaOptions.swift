public struct StringSchemaOptions: SchemaOptions, Equatable {
  /// Minimum length of string.The value must be a non-negative number.
  /// https://json-schema.org/understanding-json-schema/reference/string#length
  public let minLength: Int?

  /// Maximum length of string.The value must be a non-negative number.
  /// https://json-schema.org/understanding-json-schema/reference/string#length
  public let maxLength: Int?
  
  /// Restrict a string to a particular regular expression.
  /// https://json-schema.org/understanding-json-schema/reference/string#regexp
  public let pattern: String?
  
  /// Allows for basic semantic identification of certain kinds of string values that are commonly used.
  /// https://json-schema.org/understanding-json-schema/reference/string#format
  public let format: String?

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
