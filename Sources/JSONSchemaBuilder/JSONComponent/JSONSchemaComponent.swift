import JSONSchema

/// A component for use in ``JSONSchemaBuilder```.
public protocol JSONSchemaComponent<Output>: Sendable {
  associatedtype Output

  /// The schema that this component represents.
  var definition: Schema { get }

  /// The annotations for this component.
  var annotations: AnnotationOptions { get set }

  func validate(_ value: JSONValue) -> Validated<Output, String>
}
