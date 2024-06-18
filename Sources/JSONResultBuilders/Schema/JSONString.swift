import JSONSchema

public struct JSONString: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()
  var options: StringSchemaOptions = .options()

  public var schema: Schema {
    .string(annotations, options)
  }

  public init() {}
}

public extension JSONString {
  func minLength(_ length: Int) -> Self {
    var copy = self
    copy.options.minLength = length
    return copy
  }

  func maxLength(_ length: Int) -> Self {
    var copy = self
    copy.options.maxLength = length
    return copy
  }

  func pattern(_ pattern: String) -> Self {
    var copy = self
    copy.options.pattern = pattern
    return copy
  }

  func format(_ format: String) -> Self {
    var copy = self
    copy.options.format = format
    return copy
  }
}
