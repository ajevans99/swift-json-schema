extension Schema: Codable {
  enum CodingKeys: String, CodingKey {
    case type
    case enumValues = "enum"
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.type = try container.decode(JSONType.self, forKey: .type)
    self.enumValues = try container.decodeIfPresent([JSONValue].self, forKey: .enumValues) ?? []
    self.annotations = try AnnotationOptions(from: decoder)
    self.options = try AnySchemaOptions(from: decoder)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(enumValues, forKey: .enumValues)
    try annotations.encode(to: encoder)
    try options?.encode(to: encoder)
  }
}
