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
    public var definition: Schema {
      var copy = upstream.definition
      copy.enumValues = cases
      return copy
    }

    public var annotations: AnnotationOptions {
      get { upstream.annotations }
      set { upstream.annotations = newValue }
    }

    var upstream: Upstream
    var cases: [JSONValue]

    public init(upstream: Upstream, cases: [JSONValue]) {
      self.upstream = upstream
      self.cases = cases
    }

    public func validate(_ value: JSONValue, against validator: Validator) -> Validation<Upstream.Output> {
      for `case` in cases where `case` == value { return upstream.validate(value, against: validator) }
      return .error(.temporary("\(value) does not match any enum case."))
    }
  }
}
