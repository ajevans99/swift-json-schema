import JSONSchema

extension JSONPropertyComponents {
  public struct EmptyProperty: JSONPropertyComponent {
    public var key: String { "" }
    public var value: JSONComponents.Always { .init() }
    public var isRequired: Bool { false }

    public func validate(_ input: [String: JSONValue]) -> Validated<Void, String> {
      return .valid(())
    }
  }
}
