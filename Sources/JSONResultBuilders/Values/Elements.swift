import JSONSchema

public struct JSONStringElement: JSONRepresentable {
  public var value: JSONValue { .string(string) }

  let string: String

  public init(string: String) {
    self.string = string
  }
}

public struct JSONIntegerElement: JSONRepresentable {
  public var value: JSONValue { .integer(integer) }

  let integer: Int

  public init(integer: Int) {
    self.integer = integer
  }
}

public struct JSONNumberElement: JSONRepresentable {
  public var value: JSONValue { .number(number) }

  let number: Double

  public init(number: Double) {
    self.number = number
  }
}

public struct JSONObjectElement: JSONRepresentable {
  public var value: JSONValue { .object(properties.mapValues(\.value)) }

  let properties: [String: JSONRepresentable]

  public init(properties: [String: JSONRepresentable] = [:]) {
    self.properties = properties
  }
}

public struct JSONArrayElement: JSONRepresentable {
  public var value: JSONValue { .array(elements.map(\.value)) }

  let elements: [JSONRepresentable]

  public init(elements: [JSONRepresentable] = []) {
    self.elements = elements
  }
}

public struct JSONBooleanElement: JSONRepresentable {
  public var value: JSONValue { .boolean(boolean) }

  let boolean: Bool

  public init(boolean: Bool) {
    self.boolean = boolean
  }
}

public struct JSONNullElement: JSONRepresentable {
  public var value: JSONValue { .null }

  public init() {}
}
