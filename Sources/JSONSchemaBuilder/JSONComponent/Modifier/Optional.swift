import JSONSchema

extension JSONComponents {
  public struct OptionalNoType<Wrapped: JSONSchemaComponent>: JSONSchemaComponent {
    public var definition: Schema {
      wrapped?.definition ?? .noType()
    }

    public var annotations: AnnotationOptions {
      get {
        wrapped?.annotations ?? .annotations()
      }
      set {
        wrapped?.annotations = newValue
      }
    }

    var wrapped: Wrapped?

    public init(wrapped: Wrapped?) {
      self.wrapped = wrapped
    }

    public func validate(_ value: JSONValue) -> Validated<Wrapped.Output?, String> {
      guard let wrapped else { return .valid(nil) }
      return wrapped.validate(value).map(Optional.some)
    }
  }
}
