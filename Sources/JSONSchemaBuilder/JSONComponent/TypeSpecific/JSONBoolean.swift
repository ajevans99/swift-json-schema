import JSONSchema

/// A JSON boolean schema component for use in ``JSONSchemaBuilder``.
public struct JSONBoolean: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .boolean(annotations) }

  public init() {}

  public func validate(_ value: JSONValue, against validator: Validator) -> Validation<Bool> {
    if case .boolean(let bool) = value { return .valid(bool) }
    return .error(.typeMismatch(expected: .boolean, actual: value))
  }
}
