import JSONSchema

/// A JSON null schema component for use in ``JSONSchemaBuilder``.
public struct JSONNull: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .null(annotations) }

  public init() {}

  public func validate(_ value: JSONValue) -> Validated<Void, String> {
    if case .null = value { return .valid(()) }
    return .error("Expected null value, but got \(value)")
  }
}
