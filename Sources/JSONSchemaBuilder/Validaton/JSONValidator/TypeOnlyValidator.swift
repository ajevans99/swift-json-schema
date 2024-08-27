import JSONSchema

public struct TypeOnlyValidator: Validator {
  public func validate(integer: Int, against options: NumberSchemaOptions) -> Validation<Int> {
    .valid(integer)
  }

  public func validate(number: Double, against options: NumberSchemaOptions) -> Validation<Double> {
    .valid(number)
  }

  public func validate(string: String, against options: StringSchemaOptions) -> Validation<String> {
    .valid(string)
  }

  public func validate<Props: PropertyCollection>(object: [String: JSONValue], properties: Props, against options: ObjectSchemaOptions) -> Validation<Props.Output> {
    properties.validate(object, against: self)
  }

  public func validate<Items: JSONSchemaComponent>(array: [JSONValue], items: Items, against options: ArraySchemaOptions) -> Validation<[Items.Output]> {
    var outputs: [Items.Output] = []
    var errors: [ValidationIssue] = []
    for item in array {
      switch items.validate(item, against: self) {
      case .valid(let value): outputs.append(value)
      case .invalid(let e): errors.append(contentsOf: e)
      }
    }
    guard !errors.isEmpty else { return .valid(outputs) }
    return .invalid(errors)
  }
}
