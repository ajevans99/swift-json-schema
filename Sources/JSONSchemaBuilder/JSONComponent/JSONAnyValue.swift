import JSONSchema

/// A compoment that accepts any JSON value.
public struct JSONAnyValue: JSONSchemaComponent {
  public var schemaValue: [KeywordIdentifier: JSONValue] = [:]

  public init() {}

  public func parse(_ value: JSONValue) -> Parsed<JSONValue, String> { .valid(value) }
}
