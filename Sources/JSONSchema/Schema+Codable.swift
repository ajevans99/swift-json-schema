extension RootSchema: Codable {
  enum CodingKeys: String, CodingKey {
    case schema = "$schema"
    case id = "$id"
    case vocabulary = "$vocabulary"
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decodeIfPresent(String.self, forKey: .id)
    self.schema = try container.decodeIfPresent(String.self, forKey: .schema)
    self.vocabulary = try container.decodeIfPresent([String: JSONValue].self, forKey: .vocabulary)
    self.subschema = try Schema(from: decoder)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(schema, forKey: .schema)
    try container.encodeIfPresent(id, forKey: .id)
    try container.encodeIfPresent(vocabulary, forKey: .vocabulary)
    try subschema?.encode(to: encoder)
  }
}

extension Schema: Codable {
  enum CodingKeys: String, CodingKey {
    case type, const
    case enumValues = "enum"
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.type = try container.decodeIfPresent(JSONType.self, forKey: .type)
    self.enumValues = try container.decodeIfPresent([JSONValue].self, forKey: .enumValues)
    self.annotations = try AnnotationOptions(from: decoder)
    self.options = if let type { try AnySchemaOptions(from: decoder, typeHint: type) } else { nil }
    self.composition = try? CompositionOptions(from: decoder)
    self.const = try container.decodeIfPresent(JSONValue.self, forKey: .const)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(type, forKey: .type)
    try container.encodeIfPresent(enumValues, forKey: .enumValues)
    try annotations.encode(to: encoder)
    try options?.encode(to: encoder)
    try composition?.encode(to: encoder)
    try container.encodeIfPresent(const, forKey: .const)
  }
}
