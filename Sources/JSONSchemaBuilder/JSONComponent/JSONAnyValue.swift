import JSONSchema

/// A compoment that accepts any JSON value.
public struct JSONAnyValue: JSONSchemaComponent {
  public var schemaValue: SchemaValue = .boolean(true)

  public init() {}

  public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> { .valid(value) }
}
