public struct NumberSchemaOptions: SchemaOptions {
  /// Restrictes value to a multiple of this number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#multiples)
  public var multipleOf: Double?

  /// Maximum value.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#range)
  public var minimum: BoundaryValue?

  /// Minimum value.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#range)
  public var maximum: BoundaryValue?

  /// Represents a boundary value for a range constraint in a JSON schema.
  ///
  /// A boundary value can be either exclusive or inclusive. An exclusive boundary value means that the range does not include the boundary value itself, while an inclusive boundary value means that the range does include the boundary value.
  ///
  /// You can create a inclusive boundary value by initializing it with a floating-point or integer literal. For example:
  /// ```swift
  ///   let inclusiveBoundary: BoundaryValue = 1.0 // .inclusive(1.0)
  /// ```
  public enum BoundaryValue: Codable, Equatable, Sendable {
    case exclusive(Double)
    case inclusive(Double)
  }

  init(multipleOf: Double? = nil, minimum: BoundaryValue? = nil, maximum: BoundaryValue? = nil) {
    self.multipleOf = multipleOf
    self.minimum = minimum
    self.maximum = maximum
  }

  public static func options(
    multipleOf: Double? = nil,
    minimum: BoundaryValue? = nil,
    maximum: BoundaryValue? = nil
  ) -> Self { self.init(multipleOf: multipleOf, minimum: minimum, maximum: maximum) }

  enum CodingKeys: String, CodingKey {
    case multipleOf
    case minimum, maximum
    case exclusiveMinimum, exclusiveMaximum
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    multipleOf = try container.decodeIfPresent(Double.self, forKey: .multipleOf)

    if let exclusiveMinimum = try container.decodeIfPresent(Double.self, forKey: .exclusiveMinimum)
    {
      self.minimum = .exclusive(exclusiveMinimum)
    } else if let minimum = try container.decodeIfPresent(Double.self, forKey: .minimum) {
      self.minimum = .inclusive(minimum)
    } else {
      self.minimum = nil
    }

    if let exclusiveMaximum = try container.decodeIfPresent(Double.self, forKey: .exclusiveMaximum)
    {
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
    case .exclusive(let value): try container.encode(value, forKey: .exclusiveMaximum)
    case .inclusive(let value): try container.encode(value, forKey: .maximum)
    case .none: break
    }

    switch minimum {
    case .exclusive(let value): try container.encode(value, forKey: .exclusiveMinimum)
    case .inclusive(let value): try container.encode(value, forKey: .minimum)
    case .none: break
    }
  }
}

extension NumberSchemaOptions.BoundaryValue: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral
{
  /// Creates an inclusive boundary value with the specified floating-point literal.
  public init(floatLiteral value: FloatLiteralType) { self = .inclusive(value) }

  /// Creates an inclusive boundary value with the specified integer literal, after casting to a `Double`.
  public init(integerLiteral value: IntegerLiteralType) { self = .inclusive(Double(value)) }
}
