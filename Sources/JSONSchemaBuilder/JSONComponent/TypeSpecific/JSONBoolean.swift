import JSONSchema

/// A JSON boolean schema component for use in ``JSONSchemaBuilder``.
public struct JSONBoolean: JSONSchemaComponent {
  public var schemaValue: [KeywordIdentifier: JSONValue] = [
    Keywords.TypeKeyword.name: .string(JSONType.boolean.rawValue)
  ]

  public init() {}

  public func parse(_ value: JSONValue) -> Parsed<Bool, String> {
    if case .boolean(let bool) = value { return .valid(bool) }
    return .error("Expected a boolean value.")
  }
}
