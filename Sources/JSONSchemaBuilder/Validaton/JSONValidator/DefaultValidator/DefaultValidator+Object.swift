import JSONSchema

extension DefaultValidator {
  public func validate<Props>(object: [String: JSONValue], properties: Props, against options: ObjectSchemaOptions) -> Validation<Props.Output> where Props : PropertyCollection {


    // Handles `required` validations
    properties.validate(object, against: self)
  }
}
