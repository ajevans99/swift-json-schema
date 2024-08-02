import JSONSchema

extension JSONSchemaComponent {
  public func map<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput
  ) -> JSONComponents.Map<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }

  public func flatMap<NewComponent: JSONSchemaComponent>(
    _ transform: @Sendable @escaping (Output) -> NewComponent
  ) -> JSONComponents.FlatMap<NewComponent, Self> {
    .init(upstream: self, transform: transform)
  }

  public func compactMap<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput?
  ) -> JSONComponents.CompactMap<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }
}

extension JSONComponents {
  public struct Map<Upstream: JSONSchemaComponent, NewOutput>: JSONSchemaComponent {
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

extension JSONComponents {
  public enum Conditional<First: JSONSchemaComponent, Second: JSONSchemaComponent>: JSONSchemaComponent
  where First.Output == Second.Output {
    public var definition: Schema {
      switch self {
      case .first(let first):
        first.definition
      case .second(let second):
        second.definition
      }
    }

    public var annotations: AnnotationOptions {
      get {
        switch self {
        case .first(let first):
          first.annotations
        case .second(let second):
          second.annotations
        }
      }
      set {
        switch self {
        case .first(var first):
          first.annotations = newValue
        case .second(var second):
          second.annotations = newValue
        }
      }
    }

    case first(First)
    case second(Second)

    public func validate(_ value: JSONValue) -> Validated<First.Output, String> {
      switch self {
      case .first(let first):
        return first.validate(value)
      case .second(let second):
        return second.validate(value)
      }
    }
  }
}

extension JSONComponents {
  public struct FlatMap<NewSchemaComponent: JSONSchemaComponent, Upstream: JSONSchemaComponent>: JSONSchemaComponent {
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
    let transform: @Sendable (Upstream.Output) -> NewSchemaComponent

    init(upstream: Upstream, transform: @Sendable @escaping (Upstream.Output) -> NewSchemaComponent) {
      self.upstream = upstream
      self.transform = transform
    }

    public func validate(_ value: JSONValue) -> Validated<NewSchemaComponent.Output, String> {
      switch upstream.validate(value) {
      case .valid(let upstreamOutput):
        let newSchemaComponent = transform(upstreamOutput)
        return newSchemaComponent.validate(value)
      case .invalid(let error):
        return .invalid(error)
      }
    }
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

extension JSONComponents {
  public struct Optionally<Wrapped: JSONSchemaComponent>: JSONSchemaComponent {
    public var definition: Schema {
      wrapped.definition
    }

    public var annotations: AnnotationOptions {
      get {
        wrapped.annotations
      }
      set {
        wrapped.annotations = newValue
      }
    }

    var wrapped: Wrapped

    public init(@JSONSchemaBuilder content: () -> Wrapped) {
      self.wrapped = content()
    }

    public func validate(_ value: JSONValue) -> Validated<Wrapped.Output?, String> {
      if case .null = value {
        return .valid(nil)
      }
      return wrapped.validate(value).map(Optional.init)
    }
  }
}
