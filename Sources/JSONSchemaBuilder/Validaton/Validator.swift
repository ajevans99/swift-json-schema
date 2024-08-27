import JSONSchema

public protocol Validator: Sendable {
  func validate(number: Double, against options: NumberSchemaOptions) -> Validation<Double>
  func validate(integer: Int, against options: NumberSchemaOptions) -> Validation<Int>
  func validate(string: String, against options: StringSchemaOptions) -> Validation<String>
  func validate<Props: PropertyCollection>(object: [String: JSONValue], properties: Props, against options: ObjectSchemaOptions) -> Validation<Props.Output>
  func validate<Items: JSONSchemaComponent>(array: [JSONValue], items: Items, against options: ArraySchemaOptions) -> Validation<[Items.Output]>
}
