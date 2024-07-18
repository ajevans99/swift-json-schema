import JSONSchema

/// A JSON boolean schema component for use in ``JSONSchemaBuilder``.
public struct JSONBoolean: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .boolean(annotations) }

  public init() {}
}
