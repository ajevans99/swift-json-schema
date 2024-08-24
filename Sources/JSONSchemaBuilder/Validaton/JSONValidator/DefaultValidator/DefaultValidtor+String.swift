import JSONSchema

extension DefaultValidator {
  public func validate(string: String, against options: StringSchemaOptions) -> Validation<String> {
    var builder = ValidationErrorBuilder()

    if let maxItems = options.maxLength {

    }

    return builder.build(for: string)
  }
}

extension DefaultValidator {
  func validateNonNegativeInteger(_ value: Int) -> ValidationIssue? {
    let schema = JSONInteger().minimum(0)
    return nil
  }
}
