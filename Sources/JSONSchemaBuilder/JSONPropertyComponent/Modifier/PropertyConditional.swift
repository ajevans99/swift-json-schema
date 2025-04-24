import JSONSchema

extension JSONPropertyComponents {
  /// A component that conditionally applies one of two property collections.
  public enum Conditional<First: PropertyCollection, Second: PropertyCollection>: PropertyCollection
  where First.Output == Second.Output {
    public var schemaValue: SchemaValue {
      switch self {
      case .first(let first): first.schemaValue
      case .second(let second): second.schemaValue
      }
    }

    public var requiredKeys: [String] {
      switch self {
      case .first(let first): first.requiredKeys
      case .second(let second): second.requiredKeys
      }
    }

    case first(First)
    case second(Second)

    public func validate(_ input: [String: JSONValue]) -> Parsed<First.Output, ParseIssue> {
      switch self {
      case .first(let first): first.validate(input)
      case .second(let second): second.validate(input)
      }
    }
  }
}
