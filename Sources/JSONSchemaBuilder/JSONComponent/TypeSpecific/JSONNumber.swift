import Foundation
import JSONSchema

public protocol JSONNumberType: JSONSchemaComponent {}

/// A JSON integer schema component for use in ``JSONSchemaBuilder``.
public struct JSONInteger: JSONNumberType {
  public var schemaValue = SchemaValue.object([:])

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.integer.rawValue)
  }

  public func parse(_ value: JSONValue) -> Parsed<Int, ParseIssue> {
    guard let number = value.numberLiteral else {
      return .error(.typeMismatch(expected: .integer, actual: value))
    }
    do {
      return .valid(try number.integerValue())
    } catch {
      return .error(.numericConversionFailed(value: value, target: "Int", reason: "\(error)"))
    }
  }
}

/// A JSON number schema component for use in ``JSONSchemaBuilder``.
public struct JSONNumber: JSONNumberType {
  public var schemaValue = SchemaValue.object([:])

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.number.rawValue)
  }

  public func parse(_ value: JSONValue) -> Parsed<Double, ParseIssue> {
    guard let number = value.numberLiteral else {
      return .error(.typeMismatch(expected: .number, actual: value))
    }
    do {
      return .valid(try number.doubleValue())
    } catch {
      return .error(.numericConversionFailed(value: value, target: "Double", reason: "\(error)"))
    }
  }
}

/// A JSON number schema that extracts a `Float` directly from the original number token.
///
/// Ordinary binary rounding is allowed; overflow and nonzero underflow to zero are rejected.
public struct JSONFloat: JSONNumberType {
  public var schemaValue = SchemaValue.object([:])

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.number.rawValue)
  }

  public func parse(_ value: JSONValue) -> Parsed<Float, ParseIssue> {
    guard let number = value.numberLiteral else {
      return .error(.typeMismatch(expected: .number, actual: value))
    }
    do {
      return .valid(try number.floatValue())
    } catch {
      return .error(.numericConversionFailed(value: value, target: "Float", reason: "\(error)"))
    }
  }
}

/// A JSON number schema that extracts a Foundation `CGFloat` using its native floating-point width.
///
/// Ordinary binary rounding is allowed; overflow and nonzero underflow to zero are rejected.
public struct JSONCGFloat: JSONNumberType {
  public var schemaValue = SchemaValue.object([:])

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.number.rawValue)
  }

  public func parse(_ value: JSONValue) -> Parsed<CGFloat, ParseIssue> {
    guard let number = value.numberLiteral else {
      return .error(.typeMismatch(expected: .number, actual: value))
    }
    do {
      if CGFloat.NativeType.self == Float.self {
        return .valid(CGFloat(try number.floatValue()))
      }
      return .valid(CGFloat(try number.doubleValue()))
    } catch {
      return .error(.numericConversionFailed(value: value, target: "CGFloat", reason: "\(error)"))
    }
  }
}

/// A JSON number schema that extracts an exact Foundation `Decimal`.
///
/// Unlike converting the output of ``JSONNumber``, this component never passes
/// through `Double`. Values outside Decimal's precision or range are rejected.
public struct JSONDecimal: JSONNumberType {
  public var schemaValue = SchemaValue.object([:])

  public init() {
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.number.rawValue)
  }

  public func parse(_ value: JSONValue) -> Parsed<Decimal, ParseIssue> {
    guard let number = value.numberLiteral else {
      return .error(.typeMismatch(expected: .number, actual: value))
    }
    do {
      return .valid(try number.decimalValue())
    } catch {
      return .error(.numericConversionFailed(value: value, target: "Decimal", reason: "\(error)"))
    }
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

  /// Restricts values to exact multiples of a lossless JSON number.
  public func multipleOf(_ multipleOf: JSONNumberLiteral) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MultipleOf.name] = .numberLiteral(multipleOf)
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

  public func minimum(_ minimum: JSONNumberLiteral) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Minimum.name] = .numberLiteral(minimum)
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

  public func exclusiveMinimum(_ minimum: JSONNumberLiteral) -> Self {
    var copy = self
    copy.schemaValue[Keywords.ExclusiveMinimum.name] = .numberLiteral(minimum)
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

  public func maximum(_ maximum: JSONNumberLiteral) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Maximum.name] = .numberLiteral(maximum)
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

  public func exclusiveMaximum(_ maximum: JSONNumberLiteral) -> Self {
    var copy = self
    copy.schemaValue[Keywords.ExclusiveMaximum.name] = .numberLiteral(maximum)
    return copy
  }
}
