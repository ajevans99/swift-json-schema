import JSONSchema

/// A component for use in ``JSONSchemaBuilder```.
public protocol JSONSchemaComponent: Sendable {
  /// The schema that this component represents.
  var definition: Schema { get }

  /// The annotations for this component.
  var annotations: AnnotationOptions { get set }
}
