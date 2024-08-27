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

  public func validate(object: [String: JSONValue], against options: ObjectSchemaOptions) -> Validation<[String: JSONValue]> {
    .valid(object)
  }

  public func validate(array: [JSONValue], against options: ArraySchemaOptions) -> Validation<[JSONValue]> {
    .valid(array)
  }
}
