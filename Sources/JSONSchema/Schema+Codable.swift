import Foundation

extension Schema: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

    do {
      let rawSchema: JSONValue
      if let bool = try? container.decode(Bool.self) {
        rawSchema = .boolean(bool)
      } else {
        let schemaValue = try ObjectSchema.decodeSchemaValue(from: decoder)
        rawSchema = .object(.init(uniqueKeysWithValues: schemaValue))
      }
      try self.init(rawSchema: rawSchema, context: Context(dialect: .draft2020_12))
    } catch {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected either a boolean or an object representing a schema."
      )
    }
  }
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()

    switch schema {
    case let boolSchema as BooleanSchema: try container.encode(boolSchema)
    case let objectSchema as ObjectSchema: try container.encode(objectSchema)
    default:
      throw EncodingError.invalidValue(
        schema,
        .init(
          codingPath: [],
          debugDescription: "Expected either a boolean or an object representing a schema."
        )
      )
    }
  }
}

extension BooleanSchema: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let bool = try container.decode(Bool.self)
    self.init(
      schemaValue: bool,
      location: .init(),
      context: Context(dialect: .draft2020_12),
      documentURL: URL(string: "https://swift-json-schema.invalid/in-memory")!
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(schemaValue)
  }
}

extension ObjectSchema: Codable {
  public init(from decoder: any Decoder) throws {
    let schemaValue = try Self.decodeSchemaValue(from: decoder)

    do {
      try self.init(
        schemaValue: schemaValue,
        location: .init(),
        context: Context(dialect: .draft2020_12)
      )
    } catch {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: decoder.codingPath,
          debugDescription: "Failed to initialize schema: \(error)"
        )
      )
    }
  }

  fileprivate static func decodeSchemaValue(from decoder: any Decoder) throws -> [String: JSONValue]
  {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)

    var schemaValue = [String: JSONValue]()

    let dialect = Dialect.draft2020_12

    for keywordType in dialect.keywords {
      let key = keywordType.name
      let keyValue = DynamicCodingKey(stringValue: key)!

      if let value = try? container.decode(JSONValue.self, forKey: keyValue) {
        schemaValue[key] = value
      } else if container.contains(keyValue) {
        // Handle the case where the value is explicitly null
        schemaValue[key] = .null
      }
    }

    return schemaValue
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for keyword in keywords {
      let key = DynamicCodingKey(stringValue: type(of: keyword).name)!
      try container.encode(keyword.value, forKey: key)
    }
  }
}

struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }

  init?(stringValue: String) { self.stringValue = stringValue }

  init?(intValue: Int) { return nil }
}
