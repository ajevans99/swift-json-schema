import JSONSchema

public struct JSONNumber: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()
  var options: NumberSchemaOptions = .options()

  public var schema: Schema {
    .number(annotations, options)
  }

  public init() {}
}

public extension JSONNumber {
  func multipleOf(_ multipleOf: Double) -> JSONNumber {
    var copy = self
    copy.options.multipleOf = multipleOf
    return copy
  }

  func minimum(_ minimum: Double) -> JSONNumber {
    var copy = self
    copy.options.minimum = .inclusive(minimum)
    return copy
  }

  func exclusiveMinimum(_ minimum: Double) -> JSONNumber {
    var copy = self
    copy.options.minimum = .exclusive(minimum)
    return copy
  }

  func maximum(_ maximum: Double) -> JSONNumber {
    var copy = self
    copy.options.maximum = .inclusive(maximum)
    return copy
  }

  func exclusiveMaximum(_ maximum: Double) -> JSONNumber {
    var copy = self
    copy.options.maximum = .exclusive(maximum)
    return copy
  }
}
