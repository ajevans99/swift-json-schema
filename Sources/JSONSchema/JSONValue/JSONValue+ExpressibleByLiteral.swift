extension JSONValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) { self = .string(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: IntegerLiteralType) { self = .integer(value) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: BooleanLiteralType) { self = .boolean(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    let dictionary = Dictionary(uniqueKeysWithValues: elements)
    self = .object(dictionary)
  }
}

extension JSONValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: FloatLiteralType) { self = .number(value) }
}

extension JSONValue: ExpressibleByNilLiteral { public init(nilLiteral: ()) { self = .null } }
