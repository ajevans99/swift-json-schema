import JSONSchema

/// A component that wraps a runtime ``Schema`` instance.
/// Validation is performed using the provided schema and any valid input is
/// returned unchanged.
public struct RuntimeComponent: JSONSchemaComponent {
  public var schemaValue: SchemaValue
  let schema: Schema

  public init(rawSchema: JSONValue, dialect: Dialect = .draft2020_12) throws {
    self.schema = try Schema(rawSchema: rawSchema, context: .init(dialect: dialect))
    switch rawSchema {
    case .boolean(let bool): self.schemaValue = .boolean(bool)
    case .object(let dict): self.schemaValue = .object(dict)
    default: self.schemaValue = .object([:])
    }
  }

  public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> {
    let result = schema.validate(value)
    return result.isValid
      ? .valid(value)
      : .error(
        .compositionFailure(
          type: .allOf,
          reason: "runtime schema validation failed",
          nestedErrors: []
        )
      )
  }
}
