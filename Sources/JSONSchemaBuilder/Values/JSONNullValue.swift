import JSONSchema

/// A JSON null value component for use in ``JSONValueBuilder``.
public struct JSONNullValue: JSONValueRepresentable {
  public var value: JSONValue { .null }

  public init() {}
}
