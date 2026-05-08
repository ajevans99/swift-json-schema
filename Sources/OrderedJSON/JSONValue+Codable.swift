import OrderedCollections

extension JSONValue: Codable {
  /// Coding key that wraps any string. Used to encode objects in their
  /// stored (insertion) order so that the resulting JSON is deterministic.
  private struct AnyKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = nil
    }
    init?(intValue: Int) { return nil }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .string(let string):
      var container = encoder.singleValueContainer()
      try container.encode(string)
    case .number(let double):
      var container = encoder.singleValueContainer()
      try container.encode(double)
    case .integer(let int):
      var container = encoder.singleValueContainer()
      try container.encode(int)
    case .object(let dictionary):
      var container = encoder.container(keyedBy: AnyKey.self)
      for (key, value) in dictionary {
        try container.encode(value, forKey: AnyKey(stringValue: key))
      }
    case .array(let array):
      var container = encoder.singleValueContainer()
      try container.encode(array)
    case .boolean(let bool):
      var container = encoder.singleValueContainer()
      try container.encode(bool)
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }

  public init(from decoder: Decoder) throws {
    if let keyed = try? decoder.container(keyedBy: AnyKey.self) {
      var dictionary = OrderedDictionary<String, Self>()
      dictionary.reserveCapacity(keyed.allKeys.count)
      for key in keyed.allKeys {
        dictionary[key.stringValue] = try keyed.decode(Self.self, forKey: key)
      }
      self = .object(dictionary)
      return
    }

    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
      return
    }
    if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
      return
    }
    if let string = try? container.decode(String.self) {
      self = .string(string)
      return
    }
    if let int = try? container.decode(Int.self) {
      // Check integer before double, since all integers are also doubles.
      self = .integer(int)
      return
    }
    if let double = try? container.decode(Double.self) {
      self = .number(double)
      return
    }
    if let array = try? container.decode([Self].self) {
      self = .array(array)
      return
    }
    throw DecodingError.dataCorruptedError(
      in: container,
      debugDescription: "Unrecognized JSON value"
    )
  }
}
