import JSONSchema

extension JSONSchemaComponent {
  public func compactMap<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput?
  ) -> JSONComponents.CompactMap<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }
}

extension JSONComponents {
  public struct CompactMap<Upstream: JSONSchemaComponent, Output>: JSONSchemaComponent {
    public var definition: Schema {
      upstream.definition
    }

    public var annotations: AnnotationOptions {
      get {
        upstream.annotations
      }
      set {
        upstream.annotations = newValue
      }
    }

    var upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> Output?

    public init(
      upstream: Upstream,
      transform: @Sendable @escaping (Upstream.Output) -> Output?
    ) {
      self.upstream = upstream
      self.transform = transform
    }

    public func validate(_ value: JSONValue) -> Validated<Output, String> {
      let output = upstream.validate(value)
      switch output {
      case .valid(let a):
        guard let newOutput = transform(a) else {
          return .error("failed to process from \(value)")
        }
        return .valid(newOutput)
      case .invalid(let errors):
        return .invalid(errors)
      }
    }
  }
}
