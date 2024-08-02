import JSONSchema

/// A JSON null schema component for use in ``JSONSchemaBuilder``.
public struct JSONNull: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .null(annotations) }

  public init() {}

  public func validate(_ value: JSONValue) -> Validated<Optional<Void>, String> {
    if case .null = value {
      return .valid(.none)
    }
    return .error("Expected null value, but got \(value)")
  }
}
