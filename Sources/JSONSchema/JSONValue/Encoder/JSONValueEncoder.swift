public class JSONValueEncoder: Encoder {
  public var codingPath: [CodingKey] = []
  public var userInfo: [CodingUserInfoKey: Any] = [:]
  var result: JSONValue?

  public init() {}

  public func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
    let container = JSONKeyedEncodingContainer<Key>(encoder: self)
    return KeyedEncodingContainer(container)
  }

  public func unkeyedContainer() -> UnkeyedEncodingContainer {
    JSONUnkeyedEncodingContainer(encoder: self)
  }

  public func singleValueContainer() -> SingleValueEncodingContainer {
    JSONSingleValueEncodingContainer(encoder: self)
  }

  public func encode<T>(_ value: T) throws -> JSONValue where T: Encodable {
    try value.encode(to: self)
    return result ?? .null
  }
}

class JSONKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
  var codingPath: [CodingKey] = []
  var encoder: JSONValueEncoder
  var dictionary: [String: JSONValue] = [:]

  init(encoder: JSONValueEncoder) {
    self.encoder = encoder
  }

  deinit {
    finalizeEncoding()
  }

  func encode<T>(_ value: T, forKey key: K) throws where T: Encodable {
    let jsonEncoder = JSONValueEncoder()
    try value.encode(to: jsonEncoder)
    dictionary[key.stringValue] = jsonEncoder.result
  }

  func encodeNil(forKey key: K) throws {
    dictionary[key.stringValue] = .null
  }

  func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
    let nestedEncoder = JSONValueEncoder()
    let nestedContainer = JSONKeyedEncodingContainer<NestedKey>(encoder: nestedEncoder)
    dictionary[key.stringValue] = .object(nestedContainer.dictionary)
    return KeyedEncodingContainer(nestedContainer)
  }

  func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer {
    let nestedEncoder = JSONValueEncoder()
    let nestedContainer = JSONUnkeyedEncodingContainer(encoder: nestedEncoder)
    dictionary[key.stringValue] = .array(nestedContainer.array)
    return nestedContainer
  }

  func superEncoder() -> Encoder {
    JSONValueEncoder()
  }

  func superEncoder(forKey key: K) -> Encoder {
    let superEncoder = JSONValueEncoder()
    dictionary[key.stringValue] = .object([:])
    return superEncoder
  }

  func finalizeEncoding() {
    encoder.result = .object(dictionary)
  }
}

class JSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  var count: Int { array.count }

  var codingPath: [CodingKey] = []
  var encoder: JSONValueEncoder
  var array: [JSONValue] = []

  init(encoder: JSONValueEncoder) {
    self.encoder = encoder
  }

  deinit {
    finalizeEncoding()
  }

  func encode<T>(_ value: T) throws where T: Encodable {
    let jsonEncoder = JSONValueEncoder()
    try value.encode(to: jsonEncoder)
    array.append(jsonEncoder.result!)
  }

  func encodeNil() throws {
    array.append(.null)
  }

  func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
    let nestedEncoder = JSONValueEncoder()
    let nestedContainer = JSONKeyedEncodingContainer<NestedKey>(encoder: nestedEncoder)
    array.append(.object(nestedContainer.dictionary))
    return KeyedEncodingContainer(nestedContainer)
  }

  func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let nestedEncoder = JSONValueEncoder()
    let nestedContainer = JSONUnkeyedEncodingContainer(encoder: nestedEncoder)
    array.append(.array(nestedContainer.array))
    return nestedContainer
  }

  func superEncoder() -> Encoder {
    let superEncoder = JSONValueEncoder()
    array.append(.object([:]))
    return superEncoder
  }

  func finalizeEncoding() {
    encoder.result = .array(array)
  }
}

struct JSONSingleValueEncodingContainer: SingleValueEncodingContainer {
  var codingPath: [CodingKey] = []
  var encoder: JSONValueEncoder

  mutating func encode(_ value: String) throws {
    encoder.result = .string(value)
  }

  mutating func encode(_ value: Bool) throws {
    encoder.result = .boolean(value)
  }

  mutating func encode(_ value: Int) throws {
    encoder.result = .integer(value)
  }

  mutating func encode(_ value: Double) throws {
    encoder.result = .number(value)
  }

  mutating func encode(_ value: Float) throws {
    encoder.result = .number(Double(value))  // Convert to Double for consistency
  }

  mutating func encode(_ value: Int8) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: Int16) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: Int32) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: Int64) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: UInt) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: UInt8) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: UInt16) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: UInt32) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encode(_ value: UInt64) throws {
    encoder.result = .integer(Int(value))
  }

  mutating func encodeNil() throws {
    encoder.result = .null
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    let jsonEncoder = JSONValueEncoder()
    try value.encode(to: jsonEncoder)
    encoder.result = jsonEncoder.result
  }
}
