import JSONSchema

extension JSONPropertyComponents {
  public struct RequiredProperty<Upstream: JSONPropertyComponent, NewOutput>: JSONPropertyComponent {
    let upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> NewOutput?

    public var key: String { upstream.key }

    public let isRequired = true

    public var value: Upstream.Value { upstream.value }

    public func validate(_ input: [String: JSONValue], against validator: Validator) -> Validation<NewOutput> {
      switch upstream.validate(input, against: validator) {
      case .valid(let output):
        guard let newOutput = transform(output) else {
          return .error(.object(issue: .required(key: key), actual: input))
        }
        return .valid(newOutput)
      case .invalid(let error): return .invalid(error)
      }
    }
  }
}
