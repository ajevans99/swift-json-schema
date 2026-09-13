import Foundation
import OrderedCollections

/// Codable interoperability uses the encoder/decoder's numeric types, not raw
/// JSON tokens. Use `JSONValue.parse` and `serialized` for lossless JSON I/O.
extension JSONNumberLiteral: Codable {
  public init(from decoder: any Decoder) throws {
    try self.init(from: decoder.singleValueContainer())
  }

  fileprivate init(from container: any SingleValueDecodingContainer) throws {
    if let decimal = try? container.decode(Decimal.self), !decimal.isNaN {
      // Some decoders accept a large fractional token as an Int after binary rounding.
      if let integer = try? container.decode(Int.self), Decimal(integer) == decimal {
        self.init(integer)
      } else {
        try self.init(decimal)
      }
    } else if let integer = try? container.decode(Int.self) {
      self.init(integer)
    } else if let double = try? container.decode(Double.self), double.isFinite {
      try self.init(double)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Number cannot be represented by the decoder"
      )
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    if let integer = try? integerValue() {
      try container.encode(integer)
    } else if let double = try? doubleValue(),
      let roundTrip = try? JSONNumberLiteral(double), roundTrip == self
    {
      try container.encode(double)
    } else if let decimal = try? decimalValue() {
      try container.encode(decimal)
    } else {
      throw EncodingError.invalidValue(
        self,
        .init(
          codingPath: encoder.codingPath,
          debugDescription:
            "Number cannot be encoded without loss; use JSONValue.serialized() to preserve its token"
        )
      )
    }
  }
}

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
    case .numberLiteral(let number):
      try number.encode(to: encoder)
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
    if let number = try? JSONNumberLiteral(from: container) {
      self = .numberLiteral(number)
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
