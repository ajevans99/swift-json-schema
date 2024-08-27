import JSONSchema

extension DefaultValidator {
  public func validate<Items>(array: [JSONValue], items: Items, against options: ArraySchemaOptions) -> Validation<[Items.Output]> where Items : JSONSchemaComponent {
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
