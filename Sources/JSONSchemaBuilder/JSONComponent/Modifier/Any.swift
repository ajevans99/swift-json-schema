import JSONSchema

extension JSONSchemaComponent {
  public func eraseToAnyComponent() -> JSONComponents.AnyComponent<Self.Output> {
    .init(self)
  }
}

extension JSONComponents {
  /// Component for type erasure.
  public struct AnyComponent<Output>: JSONSchemaComponent {
    private let _validate: @Sendable (JSONValue) -> Validated<Output, String>
    public let definition: Schema
    public var annotations: AnnotationOptions

    public init<Component: JSONSchemaComponent>(_ component: Component) where Component.Output == Output {
      self.definition = component.definition
      self.annotations = component.annotations
      self._validate = component.validate
    }

    public func validate(_ value: JSONValue) -> Validated<Output, String> {
      return _validate(value)
    }
  }
}
