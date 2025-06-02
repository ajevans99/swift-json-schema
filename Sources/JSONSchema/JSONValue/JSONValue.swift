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

  public var primitive: JSONType {
    switch self {
    case .string: return .string
    case .number: return .number
    case .integer: return .integer
    case .object: return .object
    case .array: return .array
    case .boolean: return .boolean
    case .null: return .null
    }
  }

  public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
    switch (lhs, rhs) {
    case (.string(let lhsValue), .string(let rhsValue)):
      return lhsValue == rhsValue
    case (.number(let lhsValue), .number(let rhsValue)):
      return lhsValue == rhsValue
    case (.integer(let lhsValue), .integer(let rhsValue)):
      return lhsValue == rhsValue
    case (.number(let lhsValue), .integer(let rhsValue)):
      return lhsValue == Double(rhsValue)
    case (.integer(let lhsValue), .number(let rhsValue)):
      return Double(lhsValue) == rhsValue
    case (.object(let lhsValue), .object(let rhsValue)):
      return lhsValue == rhsValue
    case (.array(let lhsValue), .array(let rhsValue)):
      return lhsValue == rhsValue
    case (.boolean(let lhsValue), .boolean(let rhsValue)):
      return lhsValue == rhsValue
    case (.null, .null):
      return true
    default:
      return false
    }
  }
}

extension JSONValue {
  public var string: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  public var number: Double? {
    if case .number(let value) = self { return value }
    return nil
  }

  public var integer: Int? {
    if case .integer(let value) = self { return value }
    return nil
  }

  public var object: [String: JSONValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  public var array: [JSONValue]? {
    if case .array(let value) = self { return value }
    return nil
  }

  public var boolean: Bool? {
    if case .boolean(let value) = self { return value }
    return nil
  }

  public var isNull: Bool {
    if case .null = self { return true }
    return false
  }
}

extension JSONValue {
  public var numeric: Double? {
    switch self {
    case .integer(let integer): return Double(integer)
    case .number(let double): return double
    default: return nil
    }
  }
}

extension JSONValue: CustomStringConvertible {
  public var description: String {
    switch self {
    case .string(let value):
      return "\"\(value)\""
    case .number(let value):
      return String(value)
    case .integer(let value):
      return String(value)
    case .object(let value):
      let pairs = value.map { "\"\($0.key)\": \($0.value.description)" }
      return "{\(pairs.joined(separator: ", "))}"
    case .array(let value):
      return "[\(value.map { $0.description }.joined(separator: ", "))]"
    case .boolean(let value):
      return value ? "true" : "false"
    case .null:
      return "null"
    }
  }
}
