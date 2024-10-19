import JSONSchema

extension JSONComponents {
  /// A component that makes the output of the upstream component optional.
  /// When the wrapped component is nil, the output of validation is `.valid(nil)` and the schema accepts any input.
  public struct OptionalNoType<Wrapped: JSONSchemaComponent>: JSONSchemaComponent {
    public var schemaValue: [KeywordIdentifier : JSONValue] {
      get { wrapped?.schemaValue ?? [:] }
      set { wrapped?.schemaValue = newValue }
    }

    var wrapped: Wrapped?

    public init(wrapped: Wrapped?) { self.wrapped = wrapped }

    public func validate(_ value: JSONValue) -> Validated<Wrapped.Output?, String> {
      guard let wrapped else { return .valid(nil) }
      return wrapped.validate(value).map(Optional.some)
    }
  }
}
