import JSONSchema

public struct JSONNullValue: JSONValueRepresentable {
  public var value: JSONValue { .null }

  public init() {}
}
