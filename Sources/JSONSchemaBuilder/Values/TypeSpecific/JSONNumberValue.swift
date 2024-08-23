import JSONSchema

/// A JSON number value component for use in ``JSONValueBuilder``.
public struct JSONNumberValue: JSONValueRepresentable {
  public var value: JSONValue { .number(number) }

  let number: Double

  public init(number: Double) { self.number = number }
}
