import JSONSchema

extension JSONSchemaComponent {
  /// Modifies the validated output of a component by applying a transform. If the transform returns `nil`, the output sends a validation error.
  /// - Parameter transform: The transform to apply to the output.
  /// - Returns: A new component that applies the transform.
  public func compactMap<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput?
  ) -> JSONComponents.CompactMap<Self, NewOutput> { .init(upstream: self, transform: transform) }
}

extension JSONComponents {
  public struct CompactMap<Upstream: JSONSchemaComponent, Output>: JSONSchemaComponent {
    public var schemaValue: SchemaValue {
      get { upstream.schemaValue }
      set { upstream.schemaValue = newValue }
    }

    var upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> Output?

    public init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> Output?) {
      self.upstream = upstream
      self.transform = transform
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      let output = upstream.parse(value)
      switch output {
      case .valid(let a):
        guard let newOutput = transform(a) else { return .error(.compactMapValueNil(value: value)) }
        return .valid(newOutput)
      case .invalid(let errors): return .invalid(errors)
      }
    }
  }
}
