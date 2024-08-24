import JSONSchema

/// A compoment that accepts any JSON value.
public struct JSONAnyValue: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .noType(annotations) }

  public init() {}

  public func validate(_ value: JSONValue, against validator: Validator) -> Validation<JSONValue> { .valid(value) }
}
