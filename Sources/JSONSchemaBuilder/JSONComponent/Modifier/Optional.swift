import JSONSchema

extension JSONComponents {
  /// A component that makes the output of the upstream component optional.
  /// When the wrapped component is nil, the output of validation is `.valid(nil)` and the schema accepts any input.
  public struct OptionalNoType<Wrapped: JSONSchemaComponent>: JSONSchemaComponent {
    public var schemaValue: SchemaValue {
      get { wrapped?.schemaValue ?? .object([:]) }
      set { wrapped?.schemaValue = newValue }
    }

    var wrapped: Wrapped?

    public init(wrapped: Wrapped?) { self.wrapped = wrapped }

    public func parse(_ value: JSONValue) -> Parsed<Wrapped.Output?, ParseIssue> {
      guard let wrapped else { return .valid(nil) }
      return wrapped.parse(value).map(Optional.some)
    }
  }
}
