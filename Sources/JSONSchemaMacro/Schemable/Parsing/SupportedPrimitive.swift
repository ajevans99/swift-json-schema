enum SupportedPrimitive: String, CaseIterable {
  case double = "Double"
  case float = "Float"
  case cgFloat = "CGFloat"
  case decimal = "Decimal"
  case string = "String"
  case int = "Int"
  case bool = "Bool"
  case array = "Array"
  case dictionary = "Dictionary"

  var schema: String {
    switch self {
    case .double: "JSONNumber"
    case .float: "JSONFloat"
    case .cgFloat: "JSONCGFloat"
    case .decimal: "JSONDecimal"
    case .string: "JSONString"
    case .int: "JSONInteger"
    case .bool: "JSONBoolean"
    case .array: "JSONArray"
    case .dictionary: "JSONObject"
    }
  }

  /// Returns true if this is a scalar primitive (not array or dictionary)
  var isScalar: Bool {
    switch self {
    case .double, .float, .cgFloat, .decimal, .string, .int, .bool:
      return true
    case .array, .dictionary:
      return false
    }
  }
}
