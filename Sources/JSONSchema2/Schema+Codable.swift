extension Schema: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let bool = try? container.decode(BooleanSchema.self) {
      self.init(schema: bool, location: .init())
    } else if let schema = try? container.decode(ObjectSchema.self) {
      self.init(schema: schema, location: .init())
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected either a boolean or an object representing a schema.")
    }
  }
  
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()

    switch schema {
    case let boolSchema as BooleanSchema:
      try container.encode(boolSchema)
    case let objectSchema as ObjectSchema:
      try container.encode(objectSchema)
    default:
      throw EncodingError.invalidValue(schema, .init(codingPath: [], debugDescription: "Expected either a boolean or an object representing a schema."))
    }
  }
}

extension BooleanSchema: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let bool = try container.decode(Bool.self)
    self.init(schemaValue: bool, location: .init())
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(schemaValue)
  }
}

extension ObjectSchema: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: DynamicCodingKey.self)

    var decodedKeywords = [any Keyword]()
    var schemaValue = [String: JSONValue]()

    let dialect = Dialect.draft2020_12

    for keywordType in dialect.keywords {
      let key = keywordType.name
      if let value = try container.decodeIfPresent(JSONValue.self, forKey: .init(stringValue: key)!) {
        decodedKeywords.append(keywordType.init(schema: value, location: .init()))
        schemaValue[key] = value
      }
    }

    self.keywords = decodedKeywords
    self.location = .init()
    self.context = Context(dialect: dialect)
    self.schemaValue = schemaValue
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: DynamicCodingKey.self)
    for keyword in keywords {
      let key = DynamicCodingKey(stringValue: type(of: keyword).name)!
      try container.encode(keyword.schema, forKey: key)
    }
  }
}

//extension CodingUserInfoKey {
//  static let dialect = CodingUserInfoKey(rawValue: "dialect")!
//  static let location = CodingUserInfoKey(rawValue: "location")!
//}

struct DynamicCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int? { return nil }

  init?(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue: Int) {
    return nil
  }
}
