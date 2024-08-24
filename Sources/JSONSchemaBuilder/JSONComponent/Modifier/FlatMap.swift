import JSONSchema

extension JSONSchemaComponent {
  /// Modifies valid components by applying a transform with additional validation.
  /// - Parameter transform: The transform to apply to the output.
  /// - Returns: A new component that applies the transform.
  public func flatMap<NewComponent: JSONSchemaComponent>(
    _ transform: @Sendable @escaping (Output) -> NewComponent
  ) -> JSONComponents.FlatMap<NewComponent, Self> { .init(upstream: self, transform: transform) }
}

extension JSONComponents {
  public struct FlatMap<NewSchemaComponent: JSONSchemaComponent, Upstream: JSONSchemaComponent>:
    JSONSchemaComponent
  {
    public var definition: Schema { upstream.definition }

    public var annotations: AnnotationOptions {
      get { upstream.annotations }
      set { upstream.annotations = newValue }
    }

    var upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> NewSchemaComponent

    init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> NewSchemaComponent)
    {
      self.upstream = upstream
      self.transform = transform
    }

    public func validate(_ value: JSONValue, against validator: Validator) -> Validation<NewSchemaComponent.Output> {
      switch upstream.validate(value, against: validator) {
      case .valid(let upstreamOutput):
        let newSchemaComponent = transform(upstreamOutput)
        return newSchemaComponent.validate(value, against: validator)
      case .invalid(let error): return .invalid(error)
      }
    }
  }
}
