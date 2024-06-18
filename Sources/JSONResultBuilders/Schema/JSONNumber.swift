import JSONSchema

public struct JSONNumber: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()
  var options: NumberSchemaOptions = .options()

  public var schema: Schema { .number(annotations, options) }

  public init() {}
}

extension JSONNumber {
  public func multipleOf(_ multipleOf: Double) -> JSONNumber {
    var copy = self
    copy.options.multipleOf = multipleOf
    return copy
  }

  public func minimum(_ minimum: Double) -> JSONNumber {
    var copy = self
    copy.options.minimum = .inclusive(minimum)
    return copy
  }

  public func exclusiveMinimum(_ minimum: Double) -> JSONNumber {
    var copy = self
    copy.options.minimum = .exclusive(minimum)
    return copy
  }

  public func maximum(_ maximum: Double) -> JSONNumber {
    var copy = self
    copy.options.maximum = .inclusive(maximum)
    return copy
  }

  public func exclusiveMaximum(_ maximum: Double) -> JSONNumber {
    var copy = self
    copy.options.maximum = .exclusive(maximum)
    return copy
  }
}
