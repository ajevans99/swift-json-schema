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
    public var schemaValue: [KeywordIdentifier : JSONValue] {
      get { upstream.schemaValue }
      set { upstream.schemaValue = newValue }
    }

    var upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> NewSchemaComponent

    init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> NewSchemaComponent)
    {
      self.upstream = upstream
      self.transform = transform
    }

    public func parse(_ value: JSONValue) -> Validated<NewSchemaComponent.Output, String> {
      switch upstream.parse(value) {
      case .valid(let upstreamOutput):
        let newSchemaComponent = transform(upstreamOutput)
        return newSchemaComponent.parse(value)
      case .invalid(let error): return .invalid(error)
      }
    }
  }
}
