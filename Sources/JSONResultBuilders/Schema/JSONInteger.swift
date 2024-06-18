import JSONSchema

public struct JSONInteger: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()

  public var schema: Schema {
    .integer(annotations)
  }

  public init() {}
}
