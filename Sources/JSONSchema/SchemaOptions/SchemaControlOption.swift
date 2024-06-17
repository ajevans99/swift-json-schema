/// Often in JSON schema, `false` or a nested schema are the only valid options.
/// - SeeAlso: ``ObjectSchemaOptions/additionalProperties``
public enum SchemaControlOption: Codable, Equatable, Sendable {
  case schema(Schema)
  case disabled

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    // Attempt to decode as a Boolean first since it's unambiguous
    if let bool = try? container.decode(Bool.self), !bool {
      self = .disabled
    } else {
      let schema = try container.decode(Schema.self)
      self = .schema(schema)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .schema(let schema):
      try container.encode(schema)
    case .disabled:
      try container.encode(false)
    }
  }
}
