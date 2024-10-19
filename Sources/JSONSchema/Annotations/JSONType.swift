/// The type of a JSON value.
///
/// - SeeAlso: ``JSONValue``
public enum JSONType: String, Codable, Hashable, Sendable {
  case string
  case integer
  case number
  case object
  case array
  case boolean
  case null
}

extension JSONType {
  /// Determines whether the schema's allowed type matches the instance's actual type.
  ///
  /// This method accounts for the subtype relationship in JSON Schema where "integer" is a subset of "number".
  /// It returns `true` if the allowed type matches the instance type directly, or if the allowed type is "number"
  /// and the instance type is "integer", reflecting that integers are valid numbers.
  ///
  /// - Parameter instanceType: The actual type of the JSON instance being validated.
  /// - Returns: `true` if the instance type matches the allowed type specified in the schema; otherwise, `false`.
  public func matches(instanceType: JSONType) -> Bool {
    if self == instanceType {
      return true
    }
    // 'integer' is a subtype of 'number'
    if self == .number && instanceType == .integer {
      return true
    }
    return false
  }
}
