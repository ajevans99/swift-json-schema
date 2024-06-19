import JSONSchema

/// A component for use in ``JSONSchemaBuilder```.
public protocol JSONSchemaRepresentable {
  /// The schema that this component represents.
  var schema: Schema { get }

  /// The annotations for this component.
  var annotations: AnnotationOptions { get set }
}
