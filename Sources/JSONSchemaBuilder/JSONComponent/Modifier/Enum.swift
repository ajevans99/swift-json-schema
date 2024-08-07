import JSONSchema

extension JSONSchemaComponent {
  public func enumValues(@JSONValueBuilder with builder: () -> JSONValueRepresentable) -> JSONComponents.Enum<Self> {
    .init(upstream: self, cases: Array(builder().value))
  }
}

extension JSONComponents {
  public struct Enum<Upstream: JSONSchemaComponent>: JSONSchemaComponent {
    public var definition: Schema {
      var copy = upstream.definition
      copy.enumValues = cases
      return copy
    }

    public var annotations: AnnotationOptions {
      get {
        upstream.annotations
      }
      set {
        upstream.annotations = newValue
      }
    }

    var upstream: Upstream
    var cases: [JSONValue]

    public init(upstream: Upstream, cases: [JSONValue]) {
      self.upstream = upstream
      self.cases = cases
    }

    public func validate(_ value: JSONValue) -> Validated<Upstream.Output, String> {
      for `case` in cases {
        if `case` == value {
          return upstream.validate(value)
        }
      }
      return .error("\(value) does not match any enum case.")
    }
  }
}
