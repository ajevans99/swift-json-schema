import JSONSchema

/// A JSON null schema component for use in ``JSONSchemaBuilder``.
public struct JSONNull: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .null(annotations) }

  public init() {}
}
