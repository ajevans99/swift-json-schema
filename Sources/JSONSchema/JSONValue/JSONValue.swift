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

  public var primative: JSONType {
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

extension JSONValue {
  public var string: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }

  public var number: Double? {
    if case .number(let value) = self {
      return value
    }
    return nil
  }

  public var integer: Int? {
    if case .integer(let value) = self {
      return value
    }
    return nil
  }

  public var object: [String: JSONValue]? {
    if case .object(let value) = self {
      return value
    }
    return nil
  }

  public var array: [JSONValue]? {
    if case .array(let value) = self {
      return value
    }
    return nil
  }

  public var boolean: Bool? {
    if case .boolean(let value) = self {
      return value
    }
    return nil
  }

  public var isNull: Bool {
    if case .null = self {
      return true
    }
    return false
  }
}

extension JSONValue {
  public var numeric: Double? {
    switch self {
    case .integer(let integer):
      return Double(integer)
    case .number(let double):
      return double
    default:
      return nil
    }
  }
}
