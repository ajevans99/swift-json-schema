import JSONSchema

public struct JSONBoolean: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()

  public var schema: Schema {
    .boolean(annotations)
  }

  public init() {}
}
