import JSONSchema

/// A component that wraps a runtime ``Schema`` instance.
/// Validation is performed using the provided schema and any valid input is
/// returned unchanged.
public struct RuntimeComponent: JSONSchemaComponent {
  public enum UnsupportedSchemaTypeError: Error {
    case unsupportedType(String)
  }
  public var schemaValue: SchemaValue
  let schema: Schema

  public init(rawSchema: JSONValue, dialect: Dialect = .draft2020_12) throws {
    guard case .boolean(_) = rawSchema || case .object(_) = rawSchema else {
      throw UnsupportedSchemaTypeError.unsupportedType("Unsupported rawSchema type: \(rawSchema)")
    }
    self.schema = try Schema(rawSchema: rawSchema, context: .init(dialect: dialect))
    switch rawSchema {
    case .boolean(let bool): self.schemaValue = .boolean(bool)
    case .object(let dict): self.schemaValue = .object(dict)
    default: throw UnsupportedSchemaTypeError("Unsupported rawSchema type encountered: \(rawSchema)")
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
