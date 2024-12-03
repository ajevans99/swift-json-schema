import JSONSchema

extension JSONSchemaComponent {
  /// Maps the validated output of the upstream component to a new output type.
  /// - Parameter transform: The transform to apply to the output.
  /// - Returns: A new component that applies the transform.
  public func map<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput
  ) -> JSONComponents.Map<Self, NewOutput> { .init(upstream: self, transform: transform) }
}

extension JSONComponents {
  public struct Map<Upstream: JSONSchemaComponent, NewOutput>: JSONSchemaComponent {
    public var schemaValue: [KeywordIdentifier: JSONValue] {
      get { upstream.schemaValue }
      set { upstream.schemaValue = newValue }
    }

    var upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> NewOutput

    public init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> NewOutput) {
      self.upstream = upstream
      self.transform = transform
    }

    public func parse(_ value: JSONValue) -> Parsed<NewOutput, ParseIssue> {
      upstream.parse(value).map(transform)
    }
  }
}
