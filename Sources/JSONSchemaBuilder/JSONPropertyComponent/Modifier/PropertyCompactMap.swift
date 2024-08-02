import JSONSchema

extension JSONPropertyComponent {
  func compactMap<NewOutput>(_ transform: @Sendable @escaping (Output) -> NewOutput?) -> JSONPropertyComponents.CompactMap<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }
}

extension JSONPropertyComponents {
  public struct CompactMap<Upstream: JSONPropertyComponent, NewOutput>: JSONPropertyComponent {
    let upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> NewOutput?

    public var key: String {
      upstream.key
    }

    public let isRequired = true

    public var value: Upstream.Value {
      return upstream.value
    }

    public func validate(_ input: [String: JSONValue]) -> Validated<NewOutput, String> {
      switch upstream.validate(input) {
      case .valid(let output):
        if let newOutput = transform(output) {
          return .valid(newOutput)
        } else {
          return .error("Transformation failed for key: \(key)")
        }
      case .invalid(let error):
        return .invalid(error)
      }
    }
  }
}
