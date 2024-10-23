import JSONSchema

/// A JSON boolean schema component for use in ``JSONSchemaBuilder``.
public struct JSONBoolean: JSONSchemaComponent {
  public var schemaValue: [KeywordIdentifier: JSONValue] = [
    Keywords.TypeKeyword.name: .string(JSONType.boolean.rawValue)
  ]

  public init() {}

  public func schema() -> Schema {
    ObjectSchema(
      schemaValue: schemaValue,
      location: .init(),
      context: .init(dialect: .draft2020_12)
    )
    .asSchema()
  }

  public func parse(_ value: JSONValue) -> Validated<Bool, String> {
    if case .boolean(let bool) = value { return .valid(bool) }
    return .error("Expected a boolean value.")
  }
}
