import JSONSchema

public struct JSONBooleanSchema: JSONSchemaComponent {
  public var schemaValue: SchemaValue

  let value: Bool

  init(value: Bool) {
    self.value = value
    self.schemaValue = .boolean(value)
  }

  public func schema() -> Schema {
    definition()
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
