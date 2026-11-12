import OrderedCollections

/// A decoded JSON member name with Unicode-scalar-exact equality and hashing.
///
/// Unlike Swift String, canonically equivalent spellings remain distinct.
public struct JSONKey: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral,
  CustomStringConvertible, Comparable, Codable
{
  public let rawValue: String

  public init(_ value: String) { rawValue = value }

  public init(rawValue: String) { self.init(rawValue) }

  public init(stringLiteral value: String) { self.init(value) }

  public var description: String { rawValue }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue.unicodeScalars.elementsEqual(rhs.rawValue.unicodeScalars)
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawValue.unicodeScalars.count)
    for scalar in rawValue.unicodeScalars { hasher.combine(scalar.value) }
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue.unicodeScalars.lexicographicallyPrecedes(rhs.rawValue.unicodeScalars)
  }

  public init(from decoder: any Decoder) throws {
    self.init(try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public enum JSONKeyConversionError: Error, Equatable, Sendable {
  case canonicalCollision(first: JSONKey, second: JSONKey)
}

extension OrderedDictionary where Key == JSONKey {
  /// Imports the names still present in a Swift dictionary; previously lost names cannot be recovered.
  public init(stringKeyed dictionary: [String: Value]) {
    self.init(stringKeyedPairs: dictionary.map { ($0.key, $0.value) })
  }

  public init(stringKeyed dictionary: OrderedDictionary<String, Value>) {
    self.init(stringKeyedPairs: dictionary.map { ($0.key, $0.value) })
  }

  /// Exact duplicate names take the last value and position. No normalization is performed.
  public init<S: Sequence>(stringKeyedPairs pairs: S) where S.Element == (String, Value) {
    self.init()
    for (name, value) in pairs {
      let key = JSONKey(name)
      removeValue(forKey: key)
      self[key] = value
    }
  }

  public subscript(_ name: String) -> Value? {
    get { self[JSONKey(name)] }
    set { self[JSONKey(name)] = newValue }
  }

  @discardableResult
  public mutating func removeValue(forKey name: String) -> Value? {
    removeValue(forKey: JSONKey(name))
  }

  /// Exports without silently collapsing canonically equivalent, scalar-distinct names.
  public func stringKeyed() throws(JSONKeyConversionError) -> OrderedDictionary<String, Value> {
    var result = OrderedDictionary<String, Value>()
    result.reserveCapacity(count)
    for (key, value) in self {
      if let index = result.index(forKey: key.rawValue) {
        throw .canonicalCollision(first: JSONKey(result.keys[index]), second: key)
      }
      result[key.rawValue] = value
    }
    return result
  }

  public func stringKeyedDictionary() throws(JSONKeyConversionError) -> [String: Value] {
    Dictionary(uniqueKeysWithValues: try stringKeyed().map { ($0.key, $0.value) })
  }
}

extension Dictionary where Key == JSONKey {
  public subscript(_ name: String) -> Value? {
    get { self[JSONKey(name)] }
    set { self[JSONKey(name)] = newValue }
  }
}
