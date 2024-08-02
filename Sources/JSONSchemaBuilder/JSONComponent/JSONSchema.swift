import JSONSchema

public struct JSONSchema<Components: JSONSchemaComponent, NewOutput>: JSONSchemaComponent {
  let transform: @Sendable (Components.Output) -> NewOutput

  var components: Components

  public init(
    _ transform: @Sendable @escaping (Components.Output) -> NewOutput,
    @JSONSchemaBuilder component: () -> Components
  ) {
    self.transform = transform
    self.components = component()
  }

  public init(
    @JSONSchemaBuilder component: () -> Components
  ) where Components.Output == NewOutput {
    self.transform = { $0 }
    self.components = component()
  }

  public var definition: Schema { components.definition }

  /// The annotations for this component.
  public var annotations: AnnotationOptions {
    get {
      components.annotations
    }
    set {
      components.annotations = newValue
    }
  }

  public func validate(_ value: JSONValue) -> Validated<NewOutput, String> {
    components
      .validate(value)
      .map(transform)
  }
}
