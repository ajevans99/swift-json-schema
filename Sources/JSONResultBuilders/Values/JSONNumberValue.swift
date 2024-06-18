import JSONSchema

public struct JSONNumberValue: JSONValueRepresentable {
  public var value: JSONValue { .number(number) }

  let number: Double

  public init(number: Double) { self.number = number }
}
