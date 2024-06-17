/// A JSON value.
///
/// This type represents a JSON value, which can be a string, number, object, array, boolean, or null.
///
/// You can create a `Value` instance using the enum cases, or by using the provided
/// `ExpressibleBy*Literal` conformances.
/// ```swift
///     let value: Value = "Hello, world!"
///     let value: Value = 42
///     let value: Value = 42.0
///     let value: Value = ["key": "value"]
///     let value: Value = ["Hello", "world"]
///     let value: Value = true
///     let value: Value = false
///     let value: Value = nil
/// ```
///
/// - SeeAlso: ``JSONType``
public enum JSONValue: Hashable, Equatable, Sendable {
  case string(String)
  case number(Double)
  case integer(Int)
  case object([String: Self])
  case array([Self])
  case boolean(Bool)
  case null
}

extension JSONValue: Codable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let string):
      try container.encode(string)
    case .number(let double):
      try container.encode(double)
    case .integer(let int):
      try container.encode(int)
    case .object(let dictionary):
      try container.encode(dictionary)
    case .array(let array):
      try container.encode(array)
    case .boolean(let bool):
      try container.encode(bool)
    case .null:
      try container.encodeNil()
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      self = .string(string)
    // It is important to check for integer before double
    } else if let int = try? container.decode(Int.self) {
      self = .integer(int)
    } else if let double = try? container.decode(Double.self) {
      self = .number(double)
    } else if let dictionary = try? container.decode([String: Self].self) {
      self = .object(dictionary)
    } else if let array = try? container.decode([Self].self) {
      self = .array(array)
    } else if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unrecognized JSON value"
      )
    }
  }
}

extension JSONValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self = .string(value)
  }
}

extension JSONValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: IntegerLiteralType) {
    self = .integer(value)
  }
}

extension JSONValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: BooleanLiteralType) {
    self = .boolean(value)
  }
}

extension JSONValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: JSONValue...) {
    self = .array(elements)
  }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    let dictionary = Dictionary(uniqueKeysWithValues: elements)
    self = .object(dictionary)
  }
}

extension JSONValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: FloatLiteralType) {
    self = .number(value)
  }
}

extension JSONValue: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }
}
