import JSONSchema

/// A JSON null schema component for use in ``JSONSchemaBuilder``.
public struct JSONNull: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()

  public var schema: Schema { .null(annotations) }

  public init() {}
}
