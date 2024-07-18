enum SupportedPrimative: String, CaseIterable {
  case double = "Double"
  case float = "Float"
  case string = "String"
  case int = "Int"
  case bool = "Bool"
  case array = "Array"
  case dictionary = "Dictionary"

  var schema: String {
    switch self {
    case .double, .float:
      "JSONNumber"
    case .string:
      "JSONString"
    case .int:
      "JSONInteger"
    case .bool:
      "JSONBoolean"
    case .array:
      "JSONArray"
    case .dictionary:
      "JSONObject"
    }
  }
}
