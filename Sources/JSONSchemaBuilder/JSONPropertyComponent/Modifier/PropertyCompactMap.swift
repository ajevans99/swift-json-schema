import JSONSchema

extension JSONPropertyComponent {
  /// Transforms the validated output of the property component's value by applying a transform. If the transform returns `nil`, the output sends a validation error.
  /// This effectively transforms the validation output to be non-optional and therefore marks the property as required.
  /// - Parameter transform: The transform to apply to the output.
  /// - Returns: A new component that applies the transform.
  public func compactMap<NewOutput>(
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

    public func parse(_ input: [String: JSONValue]) -> Parsed<NewOutput, ParseIssue> {
      switch upstream.parse(input) {
      case .valid(let output):
        guard let newOutput = transform(output) else {
          // TODO: This isn't as generic as `compactMap` concept and leaks usage.
          // Would be better to use a closure for ParseIssue or change transform closure?
          return .error(.missingRequiredProperty(property: key))
        }
        return .valid(newOutput)
      case .invalid(let error): return .invalid(error)
      }
    }
  }
}
