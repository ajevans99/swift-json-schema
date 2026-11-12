import JSONSchema

public struct JSONBooleanSchema: JSONSchemaComponent {
  public var schemaValue: SchemaValue

  init(value: Bool) {
    self.schemaValue = .boolean(value)
  }

  public func schema() -> Schema {
    definition()
  }

  public func parse(_ value: JSONValue) -> Parsed<Bool, ParseIssue> {
    switch schemaValue {
    case .boolean(let allowed):
      return allowed ? .valid(true) : .error(.typeMismatch(expected: .boolean, actual: value))
    case .object:
      // The public schema can be replaced or annotated after initialization.
      // Reuse its enclosing evaluation when available, rather than the original literal.
      let result: ValidationResult
      if let evaluation = ParsingScope.current?.evaluation,
        evaluation.schema == schemaValue.value, evaluation.instance == value
      {
        result = evaluation.result
      } else {
        result = definition().validate(value)
      }
      return result.isValid ? .valid(true) : .error(.runtimeValidationIssue(result))
    }
  }
}

extension JSONBooleanSchema: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: BooleanLiteralType) {
    self.init(value: value)
  }
}
