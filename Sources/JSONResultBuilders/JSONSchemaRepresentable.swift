import JSONSchema

public protocol JSONSchemaRepresentable {
  var schema: Schema { get }

  var annotations: AnnotationOptions { get set }
}
