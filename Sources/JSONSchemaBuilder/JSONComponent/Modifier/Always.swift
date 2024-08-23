import JSONSchema

extension JSONComponents {
  /// A compoment that performs validation on wrapped component but ignores wrapped `Output`and uses original input instead.
  /// Useful schema collections where `Output` type needs to match across schemas.
  public struct Passthrough<Component: JSONSchemaComponent>: JSONSchemaComponent {
    public var definition: Schema { wrapped.definition }

    public var annotations: AnnotationOptions {
      get { wrapped.annotations }
      set { wrapped.annotations = newValue }
    }

    var wrapped: Component

    public init(wrapped: Component) {
      self.wrapped = wrapped
    }

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      wrapped.validate(value).flatMap { _ in
        return .valid(value)  // Ignore valid associated type and pass original string
      }
    }
  }
}
