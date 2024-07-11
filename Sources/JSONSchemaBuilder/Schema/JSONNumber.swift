import JSONSchema

/// A JSON number schema component for use in ``JSONSchemaBuilder``.
public struct JSONNumber: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()
  var options: NumberSchemaOptions = .options()

  public var schema: Schema { .number(annotations, options) }

  public init() {}
}

extension JSONNumber {
  /// Adds a multiple of constraint to the schema.
  /// - Parameter multipleOf: The number that the value must be a multiple of.
  /// - Returns: A new `JSONNumber` with the multiple of constraint set.
  public func multipleOf(_ multipleOf: Double) -> JSONNumber {
    var copy = self
    copy.options.multipleOf = multipleOf
    return copy
  }

  /// Adds a minimum constraint to the schema.
  /// - Parameter minimum: The minimum value that the number must be greater than or equal to.
  /// - Returns: A new `JSONNumber` with the minimum constraint set.
  public func minimum(_ minimum: Double) -> JSONNumber {
    var copy = self
    copy.options.minimum = .inclusive(minimum)
    return copy
  }

  /// Adds an exclusive minimum constraint to the schema.
  /// - Parameter minimum: The minimum value that the number must be greater than.
  /// - Returns: A new `JSONNumber` with the exclusive minimum constraint set.
  public func exclusiveMinimum(_ minimum: Double) -> JSONNumber {
    var copy = self
    copy.options.minimum = .exclusive(minimum)
    return copy
  }

  /// Adds a maximum constraint to the schema.
  /// - Parameter maximum: The maximum value that the number must be less than or equal to.
  /// - Returns: A new `JSONNumber` with the maximum constraint set.
  public func maximum(_ maximum: Double) -> JSONNumber {
    var copy = self
    copy.options.maximum = .inclusive(maximum)
    return copy
  }

  /// Adds an exclusive maximum constraint to the schema.
  /// - Parameter maximum: The maximum value that the number must be less than.
  /// - Returns: A new `JSONNumber` with the exclusive maximum constraint set.
  public func exclusiveMaximum(_ maximum: Double) -> JSONNumber {
    var copy = self
    copy.options.maximum = .exclusive(maximum)
    return copy
  }
}
