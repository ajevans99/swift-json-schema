import JSONSchema

public protocol JSONNumberType: JSONSchemaComponent { var options: NumberSchemaOptions { get set } }

/// A JSON integer schema component for use in ``JSONSchemaBuilder``.
public struct JSONInteger: JSONNumberType {
  public var annotations: AnnotationOptions = .annotations()

  public var options: NumberSchemaOptions = .options()
  public var definition: Schema { .integer(annotations, options) }

  public init() {}

  public func validate(_ value: JSONValue, against validator: Validator) -> Validation<Int> {
    if case .integer(let int) = value {
      return validator.validate(integer: int, against: options)
    }
    return .error(.typeMismatch(expected: .integer, actual: value))
  }
}

/// A JSON number schema component for use in ``JSONSchemaBuilder``.
public struct JSONNumber: JSONNumberType {
  public var annotations: AnnotationOptions = .annotations()

  public var options: NumberSchemaOptions = .options()
  public var definition: Schema { .number(annotations, options) }

  public init() {}

  public func validate(_ value: JSONValue, against validator: Validator) -> Validation<Double> {
    if case .number(let double) = value {
      return validator.validate(number: double, against: options)
    }
    return .error(.typeMismatch(expected: .number, actual: value))
  }
}

extension JSONNumberType {
  /// Restrictes value to a multiple of this number.
  /// - Parameter multipleOf: The number that the value must be a multiple of.
  /// - Returns: A new `JSONNumber` with the multiple of constraint set.
  public func multipleOf(_ multipleOf: Double?) -> Self {
    var copy = self
    copy.options.multipleOf = multipleOf
    return copy
  }

  /// Adds a minimum constraint to the schema.
  /// - Parameter boundary: The minimum value that the number must be greater than or equal to.
  /// - Returns: A new `JSONNumber` with the minimum constraint set.
  public func minimum(boundary: NumberSchemaOptions.BoundaryValue?) -> Self {
    var copy = self
    copy.options.minimum = boundary
    return copy
  }

  /// Adds a minimum constraint to the schema.
  /// - Parameter minimum: The minimum value that the number must be greater than or equal to.
  /// - Returns: A new `JSONNumber` with the minimum constraint set.
  public func minimum(_ minimum: Double?) -> Self {
    self.minimum(boundary: minimum == nil ? nil : .inclusive(minimum!))
  }

  /// Adds an exclusive minimum constraint to the schema.
  /// - Parameter minimum: The minimum value that the number must be greater than.
  /// - Returns: A new `JSONNumber` with the exclusive minimum constraint set.
  public func exclusiveMinimum(_ minimum: Double?) -> Self {
    self.minimum(boundary: minimum == nil ? nil : .exclusive(minimum!))
  }

  /// Adds a maximum constraint to the schema.
  /// - Parameter boundary: The maximum value that the number must be less than or equal to.
  /// - Returns: A new `JSONNumber` with the maximum constraint set.
  public func maximum(boundary: NumberSchemaOptions.BoundaryValue?) -> Self {
    var copy = self
    copy.options.maximum = boundary
    return copy
  }

  /// Adds a maximum constraint to the schema.
  /// - Parameter maximum: The maximum value that the number must be less than or equal to.
  /// - Returns: A new `JSONNumber` with the maximum constraint set.
  public func maximum(_ maximum: Double?) -> Self {
    self.maximum(boundary: maximum == nil ? nil : .inclusive(maximum!))
  }

  /// Adds an exclusive maximum constraint to the schema.
  /// - Parameter maximum: The maximum value that the number must be less than.
  /// - Returns: A new `JSONNumber` with the exclusive maximum constraint set.
  public func exclusiveMaximum(_ maximum: Double?) -> Self {
    self.maximum(boundary: maximum == nil ? nil : .exclusive(maximum!))
  }
}
