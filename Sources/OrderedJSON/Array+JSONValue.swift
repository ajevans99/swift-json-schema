extension Array where Element == JSONValue {
  /// Creates an array from a JSON value.
  /// If the given value is JSON array type, the elements become the elements of the array.
  /// If there anything other JSON value is given, it becomes the one and only element of the array.
  /// - Parameter value: The JSON value to convert to an array.
  public init(_ value: JSONValue) {
    switch value {
    case .string, .number, .integer, .object, .boolean, .null: self = [value]
    case .array(let array): self = array
    }
  }
}
