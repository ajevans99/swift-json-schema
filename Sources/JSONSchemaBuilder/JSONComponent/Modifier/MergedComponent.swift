import JSONSchema

extension JSONSchemaComponent {
  public func merging<C: JSONSchemaComponent>(with other: C) -> JSONComponents.MergedComponent
  where Self.Output == JSONValue, C.Output == JSONValue {
    JSONComponents.MergedComponent(components: [
      JSONComponents.AnySchemaComponent(self),
      JSONComponents.AnySchemaComponent(other),
    ])
  }
}

extension JSONComponents {
  public struct MergedComponent: JSONSchemaComponent {
    public var schemaValue: SchemaValue {
      get {
        components.reduce(into: SchemaValue.object([:])) { result, component in
          result.merge(component.schemaValue)
        }
      }
      set {}
    }

    let components: [JSONComponents.AnySchemaComponent<JSONValue>]

    public init(components: [JSONComponents.AnySchemaComponent<JSONValue>]) {
      self.components = components
    }

    public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> {
      var errors: [ParseIssue] = []
      for component in components {
        switch component.parse(value) {
        case .valid:
          continue
        case .invalid(let errs):
          errors.append(contentsOf: errs)
        }
      }
      guard errors.isEmpty else {
        return .invalid(errors)
      }
      return .valid(value)
    }
  }
}
