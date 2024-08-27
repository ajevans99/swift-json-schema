import JSONSchema

extension DefaultValidator {
  public func validate(array: [JSONValue], against options: ArraySchemaOptions) -> Validation<[JSONValue]> {
    let builder = ValidationErrorBuilder()

    return builder.build(for: array)
  }
}
