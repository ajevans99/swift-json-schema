/// The type of a JSON value.
public enum JSONType: String, Codable {
  case string
  case number
  case integer
  case object
  case array
  case boolean
  case null
}
