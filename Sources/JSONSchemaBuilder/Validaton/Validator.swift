import JSONSchema

public protocol Validator: Sendable {
  func validate(number: Double, against options: NumberSchemaOptions) -> Validation<Double>
  func validate(integer: Int, against options: NumberSchemaOptions) -> Validation<Int>
  func validate(string: String, against options: StringSchemaOptions) -> Validation<String>
}
