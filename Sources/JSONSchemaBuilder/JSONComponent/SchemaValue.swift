import JSONSchema
import OrderedCollections

public enum SchemaValue: Sendable, Equatable {
  case boolean(Bool)
  case object(OrderedDictionary<KeywordIdentifier, JSONValue>)
  /// Keywords attached to a false schema. The rejection constraint is retained
  /// separately so subsequent keyword replacement or removal cannot erase it.
  case annotatedFalse(OrderedDictionary<KeywordIdentifier, JSONValue>)

  public static func == (lhs: SchemaValue, rhs: SchemaValue) -> Bool {
    switch (lhs, rhs) {
    case (.boolean(let l), .boolean(let r)):
      return l == r
    case (.object(let l), .object(let r)):
      // JSON Schema objects are equal regardless of key order; insertion
      // order is preserved purely for deterministic emission. See #149.
      guard l.count == r.count else { return false }
      for (key, value) in l {
        guard r[key] == value else { return false }
      }
      return true
    case (.annotatedFalse(let l), .annotatedFalse(let r)):
      return SchemaValue.object(l) == SchemaValue.object(r)
    default:
      return false
    }
  }

  public var object: OrderedDictionary<KeywordIdentifier, JSONValue>? {
    switch self {
    case .boolean: return nil
    case .object(let dict): return dict
    case .annotatedFalse(var dict):
      // Keep authored allOf separate from the permanent rejection constraint.
      let authoredAllOf = dict["allOf"]
      dict["allOf"] = .array([false] + (authoredAllOf.map { [.object(["allOf": $0])] } ?? []))
      return dict
    }
  }

  public var value: JSONValue {
    switch self {
    case .boolean(let bool):
      return .boolean(bool)
    case .object(let dict):
      return .object(dict)
    case .annotatedFalse:
      return .object(object!)
    }
  }

  public subscript(key: KeywordIdentifier) -> JSONValue? {
    get {
      switch self {
      case .boolean:
        return nil
      case .object(let dict), .annotatedFalse(let dict):
        return dict[key]
      }
    }
    set {
      switch self {
      case .boolean(let allowed):
        guard let newValue else { return }
        self = allowed ? .object([key: newValue]) : .annotatedFalse([key: newValue])
      case .object(var dict):
        dict[key] = newValue
        self = .object(dict)
      case .annotatedFalse(var dict):
        dict[key] = newValue
        self = .annotatedFalse(dict)
      }
    }
  }

  public mutating func merge(_ other: SchemaValue) {
    switch (self, other) {
    case (.boolean, .boolean):
      break
    case (.boolean, .object(let dict)):
      self = .object(dict)
    case (.object(let dict), .boolean):
      self = .object(dict)
    case (.object(var dict1), .object(let dict2)):
      for (key, value2) in dict2 {
        if let value1 = dict1[key] {
          // If both values are objects, merge recursively
          var merged = value1
          merged.merge(value2)
          dict1[key] = merged
        } else {
          dict1[key] = value2
        }
      }
      self = .object(dict1)
    case (.annotatedFalse(let lhs), .object(let rhs)),
      (.object(let lhs), .annotatedFalse(let rhs)),
      (.annotatedFalse(let lhs), .annotatedFalse(let rhs)):
      var merged = SchemaValue.object(lhs)
      merged.merge(.object(rhs))
      self = .annotatedFalse(merged.object!)
    case (.annotatedFalse, .boolean):
      break
    case (.boolean, .annotatedFalse(let keywords)):
      self = .annotatedFalse(keywords)
    }
  }
}

extension SchemaValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (KeywordIdentifier, JSONValue)...) {
    var dictionary = OrderedDictionary<KeywordIdentifier, JSONValue>()
    dictionary.reserveCapacity(elements.count)
    for (key, value) in elements {
      dictionary[key] = value
    }
    self = .object(dictionary)
  }
}

extension SchemaValue: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .boolean(let bool):
      try container.encode(bool)
    case .object(let dict):
      try container.encode(JSONValue.object(dict))
    case .annotatedFalse:
      try container.encode(value)
    }
  }
}
