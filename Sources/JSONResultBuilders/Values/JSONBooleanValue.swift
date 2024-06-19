import JSONSchema

/// A JSON boolean value component for use in ``JSONValueBuilder``.
public struct JSONBooleanValue: JSONValueRepresentable {
  public var value: JSONValue { .boolean(boolean) }

  let boolean: Bool

  public init(boolean: Bool) { self.boolean = boolean }
}
