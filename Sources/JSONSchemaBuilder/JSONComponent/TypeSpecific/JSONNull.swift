import JSONSchema

/// A JSON null schema component for use in ``JSONSchemaBuilder``.
public struct JSONNull: JSONSchemaComponent {
  public var schemaValue: [KeywordIdentifier: JSONValue] = [
    Keywords.TypeKeyword.name: .string(JSONType.null.rawValue)
  ]

  public init() {}

  public func parse(_ value: JSONValue) -> Parsed<Void, ParseIssue> {
    if case .null = value { return .valid(()) }
    return .error(.typeMismatch(expected: .null, actual: value))
  }
}
