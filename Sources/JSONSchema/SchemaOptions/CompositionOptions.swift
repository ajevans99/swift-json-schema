/// Configure composition of JSON schemas. Keywords correspond to boolean algebra concepts AND, OR, XOR, and NOT.
///
/// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/combining)
public indirect enum CompositionOptions: Equatable, Sendable {
  /// To validate against `allOf`, the given data must be valid against all of the given subschemas.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/combining#allOf)
  case allOf([Schema])

  /// To validate against `anyOf`, the given data must be valid against any (one or more) of the given subschemas.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/combining#anyOf)
  case anyOf([Schema])

  /// To validate against `oneOf`, the given data must be valid against exactly one of the given subschemas.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/combining#oneOf)
  case oneOf([Schema])

  /// The `not` keyword declares that an instance validates if it doesn't validate against the given subschema.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/combining#not)
  case not(Schema)
}

extension CompositionOptions: Codable {
  enum CodingKeys: String, CodingKey {
    case allOf
    case anyOf
    case oneOf
    case not
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    if let allOf = try container.decodeIfPresent([Schema].self, forKey: .allOf) {
      self = .allOf(allOf)
    } else if let anyOf = try container.decodeIfPresent([Schema].self, forKey: .anyOf) {
      self = .anyOf(anyOf)
    } else if let oneOf = try container.decodeIfPresent([Schema].self, forKey: .oneOf) {
      self = .oneOf(oneOf)
    } else if let not = try container.decodeIfPresent(Schema.self, forKey: .not) {
      self = .not(not)
    } else {
      throw DecodingError.dataCorruptedError(
        forKey: CodingKeys.allOf,
        in: container,
        debugDescription: "Invalid CompositionOptions"
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .allOf(let schemas): try container.encode(schemas, forKey: .allOf)
    case .anyOf(let schemas): try container.encode(schemas, forKey: .anyOf)
    case .oneOf(let schemas): try container.encode(schemas, forKey: .oneOf)
    case .not(let schema): try container.encode(schema, forKey: .not)
    }
  }
}
