import JSONSchema

public struct DefaultValidator: Validator {
  func validateOption<Output>(
    _ option: JSONValue?,
    schema: some JSONSchemaComponent<Output>,
    onValid: (Output) -> Void,
    onInvalid: ([ValidationIssue]) -> Void
  ) {
    guard let option else { return }

    switch schema.validate(option, against: self) {
    case .valid(let output):
      onValid(output)
    case .invalid(let errors):
      onInvalid(errors)
    }
  }

  func validateOption<Output>(
    _ option: JSONValue?,
    schema: some JSONSchemaComponent<Output>,
    name: String,
    builder: ValidationErrorBuilder,
    onValid: (Output) -> Void
  ) {
    validateOption(option, schema: schema, onValid: onValid) { errors in
      builder.addError(.invalidOption(option: name, issues: errors))
    }
  }
}
