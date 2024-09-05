public enum JSONType: Codable, Hashable, Sendable {
  case single(JSONPrimative)
  case array([JSONPrimative])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let singleValue = try? container.decode(JSONPrimative.self) {
      self = .single(singleValue)
    } else if let arrayValue = try? container.decode([JSONPrimative].self) {
      self = .array(arrayValue)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode Type")
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .single(let value):
      try container.encode(value)
    case .array(let values):
      try container.encode(values)
    }
  }
}

/// The type of a JSON value.
///
/// - SeeAlso: ``JSONValue``
public enum JSONPrimative: String, Codable, Hashable, Sendable {
  case string
  case integer
  case number
  case object
  case array
  case boolean
  case null
}
