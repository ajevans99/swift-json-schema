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
        var result = SchemaValue.object([:])
        for component in components {
          result.merge(component.schemaValue)
        }
        result.merge(setSchemaValue)
        return result
      }
      set {
        setSchemaValue = newValue
      }
    }

    let components: [JSONComponents.AnySchemaComponent<JSONValue>]
    private var setSchemaValue: SchemaValue

    public init(components: [JSONComponents.AnySchemaComponent<JSONValue>]) {
      self.components = components
      self.setSchemaValue = .object([:])
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
