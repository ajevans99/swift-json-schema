import JSONSchema

extension DefaultValidator {
  public func validate<Items>(array: [JSONValue], items: Items, against options: ArraySchemaOptions) -> Validation<[Items.Output]> where Items : JSONSchemaComponent {
    fatalError()
  }
}
