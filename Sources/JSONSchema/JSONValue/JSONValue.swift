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

  var type: JSONPrimative {
    switch self {
    case .string:
      .string
    case .number:
      .number
    case .integer:
      .integer
    case .object:
      .object
    case .array:
      .array
    case .boolean:
      .boolean
    case .null:
      .null
    }
  }
}
