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
      let matchingSchema: JSONValue
      do {
        matchingSchema =
          try SchemaDocumentScope.current?.resolvedSchema(schemaValue.value) ?? schemaValue.value
      } catch {
        return .error(.projectionFailure(reason: "document schema resolution failed: \(error)"))
      }
      let result: ValidationResult
      if let scope = ParsingScope.current, let evaluation = scope.evaluation,
        evaluation.instance == value,
        evaluation.schema == matchingSchema
          || SchemaDocumentScope.current?
            .matchesReference(
              source: evaluation.schema,
              referenceSchema: schemaValue,
              rootSchema: scope.rootSchema
            ) == true
      {
        result = evaluation.result
      } else if let scope = ParsingScope.current {
        guard scope.allowsIndependentEvaluation,
          !ParsingScope.State.hasCustomVocabulary(schemaValue.value),
          !ParsingScope.containsReference(schemaValue.value)
        else {
          return .error(
            .projectionFailure(
              reason:
                "referenced or custom-vocabulary schemas require matching evaluation structure"
            )
          )
        }
        result = definition(context: scope.context.independentContext()).validate(value)
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
