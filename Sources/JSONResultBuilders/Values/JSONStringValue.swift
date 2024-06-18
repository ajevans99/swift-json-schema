import JSONSchema

public struct JSONStringValue: JSONValueRepresentable {
  public var value: JSONValue { .string(string) }

  let string: String

  public init(string: String) {
    self.string = string
  }
}
