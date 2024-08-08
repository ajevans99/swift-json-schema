import JSONSchema

extension JSONComponents {
  /// A component that conditionally applies one of two components based on the input value.
  public enum Conditional<First: JSONSchemaComponent, Second: JSONSchemaComponent>:
    JSONSchemaComponent
  where First.Output == Second.Output {
    public var definition: Schema {
      switch self {
      case .first(let first): first.definition
      case .second(let second): second.definition
      }
    }

    public var annotations: AnnotationOptions {
      get {
        switch self {
        case .first(let first): first.annotations
        case .second(let second): second.annotations
        }
      }
      set {
        switch self {
        case .first(var first): first.annotations = newValue
        case .second(var second): second.annotations = newValue
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
