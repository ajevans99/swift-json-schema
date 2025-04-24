import JSONSchema

public enum SchemaValue: Sendable, Equatable {
  case boolean(Bool)
  case object([KeywordIdentifier: JSONValue])

  var object: [KeywordIdentifier: JSONValue]? {
    switch self {
    case .boolean: return nil
    case .object(let dict): return dict
    }
  }

  var value: JSONValue {
    switch self {
    case .boolean(let bool):
      return .boolean(bool)
    case .object(let dict):
      return .object(dict)
    }
  }

  subscript(key: KeywordIdentifier) -> JSONValue? {
    get {
      switch self {
      case .boolean:
        return nil
      case .object(let dict):
        return dict[key]
      }
    }
    set {
      switch self {
      case .boolean:
        self = .object([key: newValue!])
      case .object(var dict):
        dict[key] = newValue
        self = .object(dict)
      }
    }
  }

  mutating func merge(_ other: SchemaValue) {
    switch (self, other) {
    case (.boolean, .boolean):
      break
    case (.boolean, .object(let dict)):
      self = .object(dict)
    case (.object(let dict), .boolean):
      self = .object(dict)
    case (.object(let dict1), .object(let dict2)):
      self = .object(dict1.merging(dict2) { current, _ in current })
    }
  }
}

extension SchemaValue: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .boolean(let bool):
      try container.encode(bool)
    case .object(let dict):
      try container.encode(dict)
    }
  }
}
