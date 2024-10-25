import JSONSchema

/// A JSON null schema component for use in ``JSONSchemaBuilder``.
public struct JSONNull: JSONSchemaComponent {
  public var schemaValue: [KeywordIdentifier: JSONValue] = [
    Keywords.TypeKeyword.name: .string(JSONType.null.rawValue)
  ]

  public init() {}

  public func parse(_ value: JSONValue) -> Validated<Void, String> {
    if case .null = value { return .valid(()) }
    return .error("Expected null value, but got \(value)")
  }
}
