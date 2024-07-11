import JSONSchema

/// A JSON integer schema component for use in ``JSONSchemaBuilder``.
public struct JSONInteger: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()

  public var schema: Schema { .integer(annotations) }

  public init() {}
}
