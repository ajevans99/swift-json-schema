import JSONSchema

/// A JSON integer schema component for use in ``JSONSchemaBuilder``.
public struct JSONInteger: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .integer(annotations) }

  public init() {}

  public func validate(_ value: JSONValue) -> Validated<Int, String> {
    if case .integer(let int) = value { return .valid(int) }
    return .error("Expected integer value.")
  }
}
