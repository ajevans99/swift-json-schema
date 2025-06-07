import JSONSchema

/// A compoment that accepts any JSON value.
public struct JSONAnyValue: JSONSchemaComponent {
  public var schemaValue: SchemaValue = .boolean(true)

  public init() {}

  /// Creates a `JSONAnyValue` from any other component. Validation is skipped
  /// but the wrapped component's schema metadata is preserved.
  public init<Component: JSONSchemaComponent>(_ component: Component) {
    self.init()
    self.schemaValue = component.schemaValue
  }

  public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> { .valid(value) }
}
