import JSONSchema

extension JSONComponents {
  /// A component that conditionally applies one of two components based on the input value.
  public enum Conditional<First: JSONSchemaComponent, Second: JSONSchemaComponent>:
    JSONSchemaComponent
  where First.Output == Second.Output {
    public var schemaValue: [KeywordIdentifier: JSONValue] {
      get {
        switch self {
        case .first(let first): first.schemaValue
        case .second(let second): second.schemaValue
        }
      }
      set {
        switch self {
        case .first(var first): first.schemaValue = newValue
        case .second(var second): second.schemaValue = newValue
        }
      }
    }

    case first(First)
    case second(Second)

    public func validate(_ value: JSONValue) -> Validated<First.Output, String> {
      switch self {
      case .first(let first): return first.validate(value)
      case .second(let second): return second.validate(value)
      }
    }
  }
}
