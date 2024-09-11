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
public enum JSONValue: Hashable, Equatable, Sendable { case string(String)
  case number(Double)
  case integer(Int)
  case object([String: Self])
  case array([Self])
  case boolean(Bool)
  case null
}

public extension JSONValue {
  static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.string(let lValue), .string(let rValue)):
      return lValue == rValue
    case (.number(let lValue), .number(let rValue)):
      return lValue == rValue
    case (.integer(let lValue), .integer(let rValue)):
      return lValue == rValue
    // For number and integer can be equal if value is the same
    case (.number(let lValue), .integer(let rValue)),
      (.integer(let rValue), .number(let lValue)):
      return lValue == Double(rValue)
    case (.object(let lValue), .object(let rValue)):
      return lValue == rValue
    case (.array(let lValue), .array(let rValue)):
      return lValue == rValue
    case (.boolean(let lValue), .boolean(let rValue)):
      return lValue == rValue
    case (.null, .null):
      return true
    default:
      return false
    }
  }
}

public extension JSONValue {
  init(_ string: String) {
    self = .string(string)
  }

  init(_ double: Double) {
    self = .number(double)
  }

  init(_ integer: Int) {
    self = .integer(integer)
  }

  init(_ object: [String: Self]) {
    self = .object(object)
  }

  init(_ array: [Self]) {
    self = .array(array)
  }

  init(_ bool: Bool) {
    self = .boolean(bool)
  }

  init(_ encodable: Codable, encoder: JSONValueEncoder = .init()) {
    self = (try? encoder.encode(encodable)) ?? .null
  }
}
