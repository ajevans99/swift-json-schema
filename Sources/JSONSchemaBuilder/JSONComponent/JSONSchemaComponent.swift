import JSONSchema

/// A component for use in ``JSONSchemaBuilder`` to build, annotate, and validate schemas.
public protocol JSONSchemaComponent<Output>: Sendable {
  associatedtype Output

  /// The schema that this component represents.
  var definition: Schema { get }

  /// The annotations for this component.
  var annotations: AnnotationOptions { get set }
  
  /// Validates a JSON value against the schema.
  /// - Parameter value: The value (aka instance, document, etc.) to validate.
  /// - Returns: A validated output or error messages.
  func validate(_ value: JSONValue) -> Validated<Output, String>
}
