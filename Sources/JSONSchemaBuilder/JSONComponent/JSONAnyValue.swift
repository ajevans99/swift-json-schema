import JSONSchema

/// A compoment that accepts any JSON value.
public struct JSONAnyValue: JSONSchemaComponent {
  public var schemaValue: [KeywordIdentifier: JSONValue] = [:]

  public init() {}

  public func validate(_ value: JSONValue) -> Validated<JSONValue, String> { .valid(value) }
}
