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
}
