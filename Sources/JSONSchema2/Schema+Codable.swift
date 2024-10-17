extension Schema: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let bool = try? container.decode(BooleanSchema.self) {
      self.init(schema: bool, location: .init(), context: Context(dialect: .draft2020_12))
    } else if let schema = try? container.decode(ObjectSchema.self) {
      self.init(schema: schema, location: .init(), context: Context(dialect: .draft2020_12))
    } else {
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
    self.init(schemaValue: bool, location: .init(), context: Context(dialect: .draft2020_12))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(schemaValue)
  }
}

extension ObjectSchema: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)

    var schemaValue = [String: JSONValue]()

    let dialect = Dialect.draft2020_12
    let context = Context(dialect: dialect)

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

    self.init(schemaValue: schemaValue, location: .init(), context: context)
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
