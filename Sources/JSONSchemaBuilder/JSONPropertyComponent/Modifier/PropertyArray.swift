import JSONSchema

extension JSONPropertyComponents {
  public struct PropertyArray<Component: PropertyCollection>: PropertyCollection {
    let components: [Component]

    public var requiredKeys: [String] {
      components.flatMap(\.requiredKeys)
    }

    public var schemaValue: SchemaValue {
      components.reduce(into: SchemaValue.object([:])) { result, component in
        result.merge(component.schemaValue)
      }
    }

    public func validate(
      _ dictionary: [String: JSONValue]
    ) -> Parsed<[Component.Output], ParseIssue> {
      var outputs: [Component.Output] = []
      var issues: [ParseIssue] = []

      for component in components {
        let result = component.validate(dictionary)
        switch result {
        case .valid(let output):
          outputs.append(output)
        case .invalid(let issue):
          issues.append(contentsOf: issue)
        }
      }

      guard issues.isEmpty else {
        return .invalid(issues)
      }
      return .valid(outputs)
    }
  }
}
