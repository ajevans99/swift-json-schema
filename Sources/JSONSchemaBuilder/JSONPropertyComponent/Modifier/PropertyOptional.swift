import JSONSchema

extension JSONPropertyComponents {
  public struct OptionalNoType<Wrapped: PropertyCollection>: PropertyCollection {
    public var schema: [String: Schema] {
      wrapped?.schema ?? [:]
    }

    public var requiredKeys: [String] {
      wrapped?.requiredKeys ?? []
    }

    var wrapped: Wrapped?

    public init(wrapped: Wrapped?) {
      self.wrapped = wrapped
    }

    public func validate(_ input: [String: JSONValue]) -> Validated<Wrapped.Output?, String> {
      wrapped?.validate(input).map(Optional.some) ?? .valid(nil)
    }
  }
}
