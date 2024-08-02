import JSONSchema

extension JSONPropertyComponents {
  public enum Conditional<First: JSONPropertyComponent, Second: JSONPropertyComponent>: JSONPropertyComponent
  where First.Output == Second.Output, First.Value == Second.Value {
    public var key: String {
      switch self {
      case .first(let first):
        first.key
      case .second(let second):
        second.key
      }
    }

    public var isRequired: Bool {
      switch self {
      case .first(let first):
        first.isRequired
      case .second(let second):
        second.isRequired
      }
    }

    public var value: First.Value {
      switch self {
      case .first(let first):
        first.value
      case .second(let second):
        second.value
      }
    }

    case first(First)
    case second(Second)

    public func validate(_ input: [String: JSONValue]) -> Validated<First.Output, String> {
      switch self {
      case .first(let first):
        first.validate(input)
      case .second(let second):
        second.validate(input)
      }
    }
  }
}
