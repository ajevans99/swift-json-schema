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
    public var schemaValue: SchemaValue {
      get {
        var schema = upstream.schemaValue
        schema[Keywords.Enum.name] = .array(cases)
        return schema
      }
      set { upstream.schemaValue = newValue }
    }

    var upstream: Upstream
    var cases: [JSONValue]

    public init(upstream: Upstream, cases: [JSONValue]) {
      self.upstream = upstream
      self.cases = cases

    }

    public func parse(_ value: JSONValue) -> Parsed<Upstream.Output, ParseIssue> {
      for `case` in cases where `case` == value { return upstream.parse(value) }
      return .error(.noEnumCaseMatch(value: value))
    }
  }
}
