public struct NumberSchemaOptions: SchemaOptions, Equatable {
  /// Restrictes value to a multiple of this number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#multiples)
  public var multipleOf: JSONValue?

  /// Restricts value to be greater than or equal to this number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#range)
  public var minimum: JSONValue?

  /// Restricts value to be greater than this number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#range)
  public var exclusiveMinimum: JSONValue?

  /// Restricts value to be less than or equal to this number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#range)
  public var maximum: JSONValue?

  /// Restricts value to be less than this number.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/numeric#range)
  public var exclusiveMaximum: JSONValue?

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
    self.multipleOf = multipleOf.map { JSONValue($0) }
    switch minimum {
    case .inclusive(let double):
      self.minimum = JSONValue(double)
    case .exclusive(let double):
      self.exclusiveMinimum = JSONValue(double)
    case .none:
      break
    }
    switch maximum {
    case .inclusive(let double):
      self.maximum = JSONValue(double)
    case .exclusive(let double):
      self.exclusiveMaximum = JSONValue(double)
    case .none:
      break
    }
  }

  public static func options(
    multipleOf: Double? = nil,
    minimum: BoundaryValue? = nil,
    maximum: BoundaryValue? = nil
  ) -> Self { self.init(multipleOf: multipleOf, minimum: minimum, maximum: maximum) }
}

extension NumberSchemaOptions.BoundaryValue: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral
{
  /// Creates an inclusive boundary value with the specified floating-point literal.
  public init(floatLiteral value: FloatLiteralType) { self = .inclusive(value) }

  /// Creates an inclusive boundary value with the specified integer literal, after casting to a `Double`.
  public init(integerLiteral value: IntegerLiteralType) { self = .inclusive(Double(value)) }
}
