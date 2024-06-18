import JSONSchema

public struct JSONBooleanValue: JSONValueRepresentable {
  public var value: JSONValue { .boolean(boolean) }

  let boolean: Bool

  public init(boolean: Bool) { self.boolean = boolean }
}
