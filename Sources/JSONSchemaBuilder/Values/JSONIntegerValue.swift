import JSONSchema

/// A JSON integer value component for use in ``JSONValueBuilder``.
public struct JSONIntegerValue: JSONValueRepresentable {
  public var value: JSONValue { .integer(integer) }

  let integer: Int

  public init(integer: Int) { self.integer = integer }
}
