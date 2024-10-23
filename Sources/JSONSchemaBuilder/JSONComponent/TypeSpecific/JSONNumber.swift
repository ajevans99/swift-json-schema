import JSONSchema

public protocol JSONNumberType: JSONSchemaComponent {}

/// A JSON integer schema component for use in ``JSONSchemaBuilder``.
public struct JSONInteger: JSONNumberType {
  public var schemaValue = [KeywordIdentifier: JSONValue]()

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.integer.rawValue)
  }

  public func schema() -> Schema {
    ObjectSchema(schemaValue: schemaValue, location: .init(), context: .init(dialect: .draft2020_12)).asSchema()
  }

  public func parse(_ value: JSONValue) -> Validated<Int, String> {
    if case .integer(let int) = value { return .valid(int) }
    return .error("Expected integer value.")
  }
}

/// A JSON number schema component for use in ``JSONSchemaBuilder``.
public struct JSONNumber: JSONNumberType {
  public var schemaValue = [KeywordIdentifier: JSONValue]()

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.number.rawValue)
  }

  public func schema() -> Schema {
    ObjectSchema(schemaValue: schemaValue, location: .init(), context: .init(dialect: .draft2020_12)).asSchema()
  }

  public func parse(_ value: JSONValue) -> Validated<Double, String> {
    if case .number(let double) = value { return .valid(double) }
    return .error("Expected a number.")
  }
}

extension JSONNumberType {
  /// Restrictes value to a multiple of this number.
  /// - Parameter multipleOf: The number that the value must be a multiple of.
  /// - Returns: A new `JSONNumber` with the multiple of constraint set.
  public func multipleOf(_ multipleOf: Double) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MultipleOf.name] = .number(multipleOf)
    return copy
  }

  /// Adds a minimum constraint to the schema.
  /// - Parameter minimum: The minimum value that the number must be greater than or equal to.
  /// - Returns: A new `JSONNumber` with the minimum constraint set.
  public func minimum(_ minimum: Double) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Minimum.name] = .number(minimum)
    return copy
  }
  
  /// Adds an exclusive minimum constraint to the schema.
  /// - Parameter minimum: The minimum value that the number must be greater than.
  /// - Returns: A new `JSONNumber` with the exclusive minimum constraint set.
  public func exclusiveMinimum(_ minimum: Double) -> Self {
    var copy = self
    copy.schemaValue[Keywords.ExclusiveMinimum.name] = .number(minimum)
    return copy
  }

  /// Adds a maximum constraint to the schema.
  /// - Parameter maximum: The maximum value that the number must be less than or equal to.
  /// - Returns: A new `JSONNumber` with the maximum constraint set.
  public func maximum(_ maximum: Double) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Maximum.name] = .number(maximum)
    return copy
  }

  /// Adds an exclusive maximum constraint to the schema.
  /// - Parameter maximum: The maximum value that the number must be less than.
  /// - Returns: A new `JSONNumber` with the exclusive maximum constraint set.
  public func exclusiveMaximum(_ maximum: Double) -> Self {
    var copy = self
    copy.schemaValue[Keywords.ExclusiveMaximum.name] = .number(maximum)
    return copy
  }
}
