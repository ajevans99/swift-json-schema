import JSONSchema

public struct JSONNull: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()

  public var schema: Schema { .null(annotations) }

  public init() {}
}
