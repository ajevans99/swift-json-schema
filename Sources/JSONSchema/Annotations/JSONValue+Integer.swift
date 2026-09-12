import OrderedJSON

extension JSONValue {
  /// JSON Schema's integer type is mathematical, independent of JSON number storage.
  package var isMathematicalInteger: Bool {
    switch self {
    case .integer: return true
    case .number(let value): return value.isFinite && value.rounded(.towardZero) == value
    default: return false
    }
  }

  /// An exactly representable Swift integer, without changing the stored JSON value.
  package var exactInteger: Int? {
    switch self {
    case .integer(let value): return value
    case .number(let value): return value.isFinite ? Int(exactly: value) : nil
    default: return nil
    }
  }
}
