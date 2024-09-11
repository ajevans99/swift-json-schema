import JSONSchema

extension JSONComponents {
  /// A component that makes the output of the upstream component optional.
  /// When the wrapped component is nil, the output of validation is `.valid(nil)` and the schema accepts any input.
  public struct OptionalNoType<Wrapped: JSONSchemaComponent>: JSONSchemaComponent {
    public var definition: Schema { wrapped?.definition ?? .noType() }

    public var annotations: AnnotationOptions {
      get { wrapped?.annotations ?? .annotations() }
      set { wrapped?.annotations = newValue }
    }

    var wrapped: Wrapped?

    public init(wrapped: Wrapped?) { self.wrapped = wrapped }

    public func validate(_ value: JSONValue, against validator: Validator) -> Validation<Wrapped.Output?> {
      guard let wrapped else { return .valid(nil) }
      return wrapped.validate(value, against: validator).map(Optional.some)
    }
  }
}
