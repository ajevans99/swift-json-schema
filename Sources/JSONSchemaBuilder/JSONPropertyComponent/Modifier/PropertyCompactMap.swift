import JSONSchema

extension JSONPropertyComponent {
  /// Transforms the validated output of the property component's value by applying a transform. If the transform returns `nil`, the output sends a validation error.
  /// This effectively transforms the validation output to be non-optional and therefore marks the property as required.
  /// - Parameter transform: The transform to apply to the output.
  /// - Returns: A new component that applies the transform.
  func compactMap<NewOutput>(
    _ transform: @Sendable @escaping (Output) -> NewOutput?
  ) -> JSONPropertyComponents.CompactMap<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }
}

extension JSONPropertyComponents {
  public struct CompactMap<Upstream: JSONPropertyComponent, NewOutput>: JSONPropertyComponent {
    let upstream: Upstream
    let transform: @Sendable (Upstream.Output) -> NewOutput?

    public var key: String { upstream.key }

    public let isRequired = true

    public var value: Upstream.Value { upstream.value }

    public func parse(_ input: [String: JSONValue]) -> Parsed<NewOutput, String> {
      switch upstream.parse(input) {
      case .valid(let output):
        guard let newOutput = transform(output) else {
          return .error("Transformation failed for key: \(key)")
        }
        return .valid(newOutput)
      case .invalid(let error): return .invalid(error)
      }
    }
  }
}
