extension JSONValue: Codable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let string): try container.encode(string)
    case .number(let double): try container.encode(double)
    case .integer(let int): try container.encode(int)
    case .object(let dictionary): try container.encode(dictionary)
    case .array(let array): try container.encode(array)
    case .boolean(let bool): try container.encode(bool)
    case .null: try container.encodeNil()
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let int = try? container.decode(Int.self) {
      // It is important to check for integer before double, as all integers are also doubles.
      self = .integer(int)
    } else if let double = try? container.decode(Double.self) {
      self = .number(double)
    } else if let dictionary = try? container.decode([String: Self].self) {
      self = .object(dictionary)
    } else if let array = try? container.decode([Self].self) {
      self = .array(array)
    } else if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unrecognized JSON value"
      )
    }
  }
}
