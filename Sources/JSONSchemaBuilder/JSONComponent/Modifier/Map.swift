import JSONSchema

extension JSONSchemaComponent {
  public func map<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput
  ) -> JSONComponents.Map<Self, NewOutput> { .init(upstream: self, transform: transform) }
}

extension JSONComponents {
  public struct Map<Upstream: JSONSchemaComponent, NewOutput>: JSONSchemaComponent {
    public var definition: Schema { upstream.definition }

    public var annotations: AnnotationOptions {
      get { upstream.annotations }
      set { upstream.annotations = newValue }
    }

    var upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> NewOutput

    public init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> NewOutput) {
      self.upstream = upstream
      self.transform = transform
    }

    public func validate(_ value: JSONValue) -> Validated<NewOutput, String> {
      upstream.validate(value).map(transform)
    }
  }
}
