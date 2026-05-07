import OrderedCollections

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
/// Object values are stored in an ``OrderedCollections/OrderedDictionary`` so
/// that the insertion order of keys is preserved by encoding, equality (which
/// is order-insensitive) is unchanged, and downstream consumers get
/// reproducible JSON output. See issue #149 for the rationale.
///
/// - SeeAlso: ``JSONType``
public enum JSONValue: Hashable, Equatable, Sendable {
  case string(String)
  case number(Double)
  case integer(Int)
  case object(OrderedDictionary<String, Self>)
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

  public func hash(into hasher: inout Hasher) {
    switch self {
    case .string(let value):
      hasher.combine(0)
      // Match the unicode-scalar equality used by `==` so equal strings hash equally.
      hasher.combine(Array(value.unicodeScalars))
    case .number(let value):
      hasher.combine(1)
      hasher.combine(value)
    case .integer(let value):
      // Hash integers as their double form so `.integer(1) == .number(1.0)`
      // continue to share a hash bucket.
      hasher.combine(1)
      hasher.combine(Double(value))
    case .object(let dictionary):
      hasher.combine(2)
      // JSON objects are unordered for equality, so hash order-insensitively
      // via XOR of per-pair hashes.
      var combined: Int = 0
      for (key, value) in dictionary {
        var pairHasher = Hasher()
        pairHasher.combine(key)
        pairHasher.combine(value)
        combined ^= pairHasher.finalize()
      }
      hasher.combine(combined)
    case .array(let array):
      hasher.combine(3)
      hasher.combine(array)
    case .boolean(let value):
      hasher.combine(4)
      hasher.combine(value)
    case .null:
      hasher.combine(5)
    }
  }

  public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
    switch (lhs, rhs) {
    case (.string(let lhsValue), .string(let rhsValue)):
      // Swift uses canonical equality for strings, but JSON string equality is based on Unicode scalar equality.
      // For example, "ä" (U+00E4) and "ä" (U+0061 U+0308) are canonically equal in Swift, but not in JSON.
      // See `const.json` test cases in JSON Schema Test Suite for more details.
      return lhsValue.unicodeScalars.elementsEqual(rhsValue.unicodeScalars)
    case (.number(let lhsValue), .number(let rhsValue)):
      return lhsValue == rhsValue
    case (.integer(let lhsValue), .integer(let rhsValue)):
      return lhsValue == rhsValue
    case (.number(let lhsValue), .integer(let rhsValue)):
      return lhsValue == Double(rhsValue)
    case (.integer(let lhsValue), .number(let rhsValue)):
      return Double(lhsValue) == rhsValue
    case (.object(let lhsValue), .object(let rhsValue)):
      // JSON objects compare on key membership, not insertion order, even
      // though we store keys in an OrderedDictionary for deterministic
      // emission. See issue #149.
      guard lhsValue.count == rhsValue.count else { return false }
      for (key, value) in lhsValue {
        guard rhsValue[key] == value else { return false }
      }
      return true
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

  public var object: OrderedDictionary<String, JSONValue>? {
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
