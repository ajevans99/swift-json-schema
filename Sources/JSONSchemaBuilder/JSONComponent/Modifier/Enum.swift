import JSONSchema

extension JSONSchemaComponent {
  /// Adds an `enum` constraint to the schema.
  /// - Parameter builder: A closure that returns one or more of enum values.
  /// - Returns: A new component with the `enum` constraint applied.
  public func enumValues(
    @JSONValueBuilder with builder: () -> JSONValueRepresentable
  ) -> JSONComponents.Enum<Self> { .init(upstream: self, cases: Array(builder().value)) }
}

extension JSONComponents {
  public struct Enum<Upstream: JSONSchemaComponent>: JSONSchemaComponent {
    public var schemaValue: [KeywordIdentifier: JSONValue] {
      get {
        upstream.schemaValue
          .merging([Keywords.Enum.name: .array(cases)], uniquingKeysWith: { $1 })
      }
      set { upstream.schemaValue = newValue }
    }

    var upstream: Upstream
    var cases: [JSONValue]

    public init(upstream: Upstream, cases: [JSONValue]) {
      self.upstream = upstream
      self.cases = cases

    }

    public func validate(_ value: JSONValue) -> Validated<Upstream.Output, String> {
      for `case` in cases where `case` == value { return upstream.validate(value) }
      return .error("\(value) does not match any enum case.")
    }
  }
}
