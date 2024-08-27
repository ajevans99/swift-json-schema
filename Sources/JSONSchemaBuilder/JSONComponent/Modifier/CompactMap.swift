import JSONSchema

extension JSONSchemaComponent {
  /// Modifies the validated output of a component by applying a transform. If the transform returns `nil`, the output sends a validation error.
  /// - Parameter transform: The transform to apply to the output.
  /// - Returns: A new component that applies the transform.
  public func compactMap<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput?
  ) -> JSONComponents.CompactMap<Self, NewOutput> { .init(upstream: self, transform: transform, fallback: { _ in .compactMapTranformNil }) }


  /// Modifies the validated output of a component by applying a transform. If the transform returns `nil`, the output sends a validation error.
  /// - Parameters:
  ///   - transform: The transform to apply to the output.
  ///   - fallback: The error validaiton issue returned when the tranform closure returns `nil`
  /// - Returns: A new component that applies the transform.
  public func compactMap<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput?,
    fallback: @Sendable @escaping (Output) -> ValidationIssue
  ) -> JSONComponents.CompactMap<Self, NewOutput> { .init(upstream: self, transform: transform, fallback: fallback) }
}

extension JSONComponents {
  public struct CompactMap<Upstream: JSONSchemaComponent, Output>: JSONSchemaComponent {
    public var definition: Schema { upstream.definition }

    public var annotations: AnnotationOptions {
      get { upstream.annotations }
      set { upstream.annotations = newValue }
    }

    var upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> Output?
    let fallback: @Sendable (Upstream.Output) -> ValidationIssue

    public init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> Output?, fallback: @Sendable @escaping (Upstream.Output) -> ValidationIssue) {
      self.upstream = upstream
      self.transform = transform
      self.fallback = fallback
    }

    public func validate(_ value: JSONValue, against validator: Validator) -> Validation<Output> {
      let output = upstream.validate(value, against: validator)
      switch output {
      case .valid(let a):
        guard let newOutput = transform(a) else { return .error(fallback(a)) }
        return .valid(newOutput)
      case .invalid(let errors): return .invalid(errors)
      }
    }
  }
}
