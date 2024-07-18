import JSONSchema

/// A JSON number schema component for use in ``JSONSchemaBuilder``.
public struct JSONNumber: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()
  var options: NumberSchemaOptions = .options()

  public var definition: Schema { .number(annotations, options) }

  public init() {}
}

extension JSONNumber {
  /// Adds a multiple of constraint to the schema.
  /// - Parameter multipleOf: The number that the value must be a multiple of.
  /// - Returns: A new `JSONNumber` with the multiple of constraint set.
  public func multipleOf(_ multipleOf: Double?) -> JSONNumber {
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
  public func minimum(_ minimum: Double?) -> JSONNumber {
    self.minimum(boundary: minimum == nil ? nil : .inclusive(minimum!))
  }

  /// Adds an exclusive minimum constraint to the schema.
  /// - Parameter minimum: The minimum value that the number must be greater than.
  /// - Returns: A new `JSONNumber` with the exclusive minimum constraint set.
  public func exclusiveMinimum(_ minimum: Double?) -> JSONNumber {
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
  public func maximum(_ maximum: Double?) -> JSONNumber {
    self.maximum(boundary: maximum == nil ? nil : .inclusive(maximum!))
  }

  /// Adds an exclusive maximum constraint to the schema.
  /// - Parameter maximum: The maximum value that the number must be less than.
  /// - Returns: A new `JSONNumber` with the exclusive maximum constraint set.
  public func exclusiveMaximum(_ maximum: Double?) -> JSONNumber {
    self.maximum(boundary: maximum == nil ? nil : .exclusive(maximum!))
  }
}
