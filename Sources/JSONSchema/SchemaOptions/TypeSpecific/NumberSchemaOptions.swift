public struct NumberSchemaOptions: SchemaOptions {
  /// Restrictes value to a multiple of this number.
  /// https://json-schema.org/understanding-json-schema/reference/numeric#multiples
  public let multipleOf: Double?

  /// Maximum value.
  /// https://json-schema.org/understanding-json-schema/reference/numeric#range
  public let minimum: RangeValue?

  /// Minimum value.
  /// https://json-schema.org/understanding-json-schema/reference/numeric#range
  public let maximum: RangeValue?

  public enum RangeValue: Codable {
    case exclusive(Double)
    case inclusive(Double)
  }

  init(
    multipleOf: Double? = nil,
    minimum: RangeValue? = nil,
    maximum: RangeValue? = nil
  ) {
    self.multipleOf = multipleOf
    self.minimum = minimum
    self.maximum = maximum
  }

  public static func options(
    multipleOf: Double? = nil,
    minimum: RangeValue? = nil,
    maximum: RangeValue? = nil
  ) -> Self {
    self.init(multipleOf: multipleOf, minimum: minimum, maximum: maximum)
  }

  enum CodingKeys: String, CodingKey {
    case multipleOf
    case minimum, maximum
    case exclusiveMinimum, exclusiveMaximum
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    multipleOf = try container.decodeIfPresent(Double.self, forKey: .multipleOf)

    if let exclusiveMinimum = try container.decodeIfPresent(Double.self, forKey: .exclusiveMinimum) {
      self.minimum = .exclusive(exclusiveMinimum)
    } else if let minimum = try container.decodeIfPresent(Double.self, forKey: .minimum) {
      self.minimum = .inclusive(minimum)
    } else {
      self.minimum = nil
    }

    if let exclusiveMaximum = try container.decodeIfPresent(Double.self, forKey: .exclusiveMaximum) {
      self.maximum = .exclusive(exclusiveMaximum)
    } else if let maximum = try container.decodeIfPresent(Double.self, forKey: .maximum) {
      self.maximum = .inclusive(maximum)
    } else {
      self.maximum = nil
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(multipleOf, forKey: .multipleOf)

    switch maximum {
    case .exclusive(let value):
      try container.encode(value, forKey: .exclusiveMaximum)
    case .inclusive(let value):
      try container.encode(value, forKey: .maximum)
    case .none:
      break
    }

    switch minimum {
    case .exclusive(let value):
      try container.encode(value, forKey: .exclusiveMinimum)
    case .inclusive(let value):
      try container.encode(value, forKey: .minimum)
    case .none:
      break
    }
  }
}
