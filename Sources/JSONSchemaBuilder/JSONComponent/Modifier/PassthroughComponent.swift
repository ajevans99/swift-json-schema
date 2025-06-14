import JSONSchema

extension JSONComponents {
  /// A component that performs validation on wrapped component but ignores wrapped `Output`and uses original input instead.
  /// Useful schema collections where `Output` type needs to match across schemas.
  public struct PassthroughComponent<Component: JSONSchemaComponent>: JSONSchemaComponent {
    public var schemaValue: SchemaValue {
      get { wrapped.schemaValue }
      set { wrapped.schemaValue = newValue }
    }

    var wrapped: Component

    public init(wrapped: Component) { self.wrapped = wrapped }

    public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> {
      wrapped.parse(value)
        .flatMap { _ in .valid(value)  // Ignore valid associated type and pass original string
        }
    }
  }
}
