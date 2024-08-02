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
  var type: JSONType {
    switch self {
    case .string:
      return .string
    case .number:
      return .number
    case .integer:
      return .integer
    case .object:
      return .object
    case .array:
      return .array
    case .boolean:
      return .boolean
    case .null:
      return .null
    }
  }
}
