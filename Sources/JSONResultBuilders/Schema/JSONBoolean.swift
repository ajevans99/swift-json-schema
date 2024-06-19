import JSONSchema

/// A JSON boolean schema component for use in ``JSONSchemaBuilder``.
public struct JSONBoolean: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()

  public var schema: Schema { .boolean(annotations) }

  public init() {}
}
