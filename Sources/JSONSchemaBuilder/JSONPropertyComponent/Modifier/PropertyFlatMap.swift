import JSONSchema

extension JSONPropertyComponent {
  /// Flattens a double-optional output to a single optional.
  /// This is specifically useful for optional properties that use `.orNull()`,
  /// which creates a double-optional (T??) that needs to be flattened to T?.
  /// - Returns: A new component that flattens the double-optional output.
  public func flatMapOptional<Wrapped>()
    -> JSONPropertyComponents.FlatMapOptional<Self, Wrapped>
  where Output == Wrapped?? {
    .init(upstream: self)
  }
}

extension JSONPropertyComponents {
  public struct FlatMapOptional<Upstream: JSONPropertyComponent, Wrapped>: JSONPropertyComponent
  where Upstream.Output == Wrapped?? {
    let upstream: Upstream

    public var key: String { upstream.key }

    public var isRequired: Bool { upstream.isRequired }

    public var value: Upstream.Value { upstream.value }

    public func parse(_ input: [String: JSONValue]) -> Parsed<Wrapped?, ParseIssue> {
      switch upstream.parse(input) {
      case .valid(let output):
        // Flatten T?? to T?
        // If output is nil (property missing), return nil
        // If output is .some(nil) (property present but null), return nil
        // If output is .some(.some(value)), return value
        return .valid(output.flatMap { $0 })
      case .invalid(let error): return .invalid(error)
      }
    }
  }
}
