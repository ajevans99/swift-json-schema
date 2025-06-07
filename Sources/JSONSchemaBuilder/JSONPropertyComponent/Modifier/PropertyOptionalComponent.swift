import JSONSchema

extension JSONPropertyComponents {
  /// A property collection that wraps another property collection and makes it's validation result optional.
  public struct OptionalComponent<Wrapped: PropertyCollection>: PropertyCollection {
    public var schemaValue: SchemaValue { wrapped?.schemaValue ?? .object([:]) }

    public var requiredKeys: [String] { wrapped?.requiredKeys ?? [] }

    var wrapped: Wrapped?

    public init(wrapped: Wrapped?) { self.wrapped = wrapped }

    public func validate(_ input: [String: JSONValue]) -> Parsed<Wrapped.Output?, ParseIssue> {
      wrapped?.validate(input).map(Optional.some) ?? .valid(nil)
    }
  }
}
