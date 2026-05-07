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
