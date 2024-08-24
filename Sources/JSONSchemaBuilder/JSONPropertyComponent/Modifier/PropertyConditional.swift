import JSONSchema

extension JSONPropertyComponents {
  /// A component that conditionally applies one of two property collections.
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

    public func validate(_ input: [String: JSONValue], against validator: Validator) -> Validation<First.Output> {
      switch self {
      case .first(let first): first.validate(input, against: validator)
      case .second(let second): second.validate(input, against: validator)
      }
    }
  }
}
