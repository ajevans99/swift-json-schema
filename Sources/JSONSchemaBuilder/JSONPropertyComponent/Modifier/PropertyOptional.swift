import JSONSchema

extension JSONPropertyComponents {
  public struct OptionalNoType<Wrapped: JSONPropertyComponent>: JSONPropertyComponent {
    public var key: String {
      return wrapped?.key ?? ""
    }

    public let isRequired: Bool = false

    public var value: Wrapped.Value {
      guard let value = wrapped?.value else {
        fatalError("Cannot access value of \(Self.self)")
      }
      return value
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
