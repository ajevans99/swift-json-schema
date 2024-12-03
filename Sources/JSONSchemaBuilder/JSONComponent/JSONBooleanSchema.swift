import JSONSchema

public struct JSONBooleanSchema: JSONSchemaComponent {
  // TODO: Need to change JSONSchemaComponent to support `false`/`true` schemas
  public var schemaValue: [KeywordIdentifier: JSONValue] {
    get { [:] }
    set { fatalError("Cannot set schemaValue on JSONBooleanSchema") }
  }

  let value: Bool

  public func schema() -> Schema {
    BooleanSchema(schemaValue: value, location: .init(), context: .init(dialect: .draft2020_12))
      .asSchema()
  }

  public func parse(_ value: JSONValue) -> Parsed<Bool, ParseIssue> {
    self.value ? .valid(true) : .error(.typeMismatch(expected: .boolean, actual: value))
  }
}

extension JSONBooleanSchema: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: BooleanLiteralType) {
    self.init(value: value)
  }
}
