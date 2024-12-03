import JSONSchema

/// A JSON string schema component for use in ``JSONSchemaBuilder``.
public struct JSONString: JSONSchemaComponent {
  public var schemaValue = [KeywordIdentifier: JSONValue]()

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.string.rawValue)
  }

  public func parse(_ value: JSONValue) -> Parsed<String, ParseIssue> {
    if case .string(let string) = value { return .valid(string) }
    return .error(.typeMismatch(expected: .string, actual: value))
  }
}

extension JSONString {
  /// Adds a minimum length constraint to the schema.
  /// - Parameter length: The minimum length that the string must be greater than or equal to.
  /// - Returns: A new `JSONString` with the minimum length constraint set.
  public func minLength(_ length: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MinLength.name] = .integer(length)
    return copy
  }

  /// Adds a maximum length constraint to the schema.
  /// - Parameter length: The maximum length that the string must be less than or equal to.
  /// - Returns: A new `JSONString` with the maximum length constraint set.
  public func maxLength(_ length: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MaxLength.name] = .integer(length)
    return copy
  }

  /// Adds a pattern constraint to the schema.
  /// - Parameter pattern: The regular expression pattern that the string must match.
  /// - Returns: A new `JSONString` with the pattern constraint set.
  public func pattern(_ pattern: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Pattern.name] = .string(pattern)
    return copy
  }

  /// Adds constraint for basic semantic identification of certain kinds of string values that are commonly used.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/string#format)
  /// - Parameter format: The format that the string must adhere to.
  /// - Returns: A new `JSONString` with the format constraint set.
  public func format(_ format: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Format.name] = .string(format)
    return copy
  }
}
