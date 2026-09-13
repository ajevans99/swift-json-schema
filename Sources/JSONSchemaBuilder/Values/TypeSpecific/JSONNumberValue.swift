import JSONSchema

/// A JSON number value component for use in ``JSONValueBuilder``.
public struct JSONNumberValue: JSONValueRepresentable {
  public let value: JSONValue

  public init(number: Double) {
    self.value = .number(number)
  }

  public init(number: JSONNumberLiteral) { self.value = .numberLiteral(number) }
}
