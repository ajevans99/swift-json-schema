import JSONSchema

extension JSONPropertyComponents {
  public enum Conditional<First: PropertyCollection, Second: PropertyCollection>: PropertyCollection
  where First.Output == Second.Output {
    public var schema: [String: Schema] {
      switch self {
      case .first(let first): first.schema
      case .second(let second): second.schema
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

    public func validate(_ input: [String: JSONValue]) -> Validated<First.Output, String> {
      switch self {
      case .first(let first): first.validate(input)
      case .second(let second): second.validate(input)
      }
    }
  }
}
