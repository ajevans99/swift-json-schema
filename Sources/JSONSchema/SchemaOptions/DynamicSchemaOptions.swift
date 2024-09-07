/// When there is not type provided for a schema, this options type will be used to store options that will be determined at runtime.
/// In the following schema example,
/// ```json
/// {
///   "$schema": "https://json-schema.org/draft/2020-12/schema",
///   "uniqueItems": true,
///   "multipleOf": 5
/// }
/// ```
/// `uniqueItems` applies to array instances and `multipleOf` applies to numbers.
/// Without an explicit `"type": "array"` or `"type": "number"`, it isn't know until runtime which options should apply, so ``DynamicSchemaOptions`` stores them all.
/// This is also useful for cases where the array type is heterogeneous, like `"type": ["array", "number"]`.
public struct DynamicSchemaOptions: SchemaOptions {
  public let array: ArraySchemaOptions?
  public let number: NumberSchemaOptions?
  public let object: ObjectSchemaOptions?
  public let string: StringSchemaOptions?

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.array = try? container.decode(ArraySchemaOptions.self).nilIfEmpty
    self.number = try? container.decode(NumberSchemaOptions.self).nilIfEmpty
    self.object = try? container.decode(ObjectSchemaOptions.self).nilIfEmpty
    self.string = try? container.decode(StringSchemaOptions.self).nilIfEmpty
  }

  public func encode(to encoder: any Encoder) throws {
    try array?.encode(to: encoder)
    try number?.encode(to: encoder)
    try object?.encode(to: encoder)
    try string?.encode(to: encoder)
  }

  init(
    array: ArraySchemaOptions? = nil,
    number: NumberSchemaOptions? = nil,
    object: ObjectSchemaOptions? = nil,
    string: StringSchemaOptions? = nil
  ) {
    self.array = array
    self.number = number
    self.object = object
    self.string = string
  }

  static func options(
    array: ArraySchemaOptions? = nil,
    number: NumberSchemaOptions? = nil,
    object: ObjectSchemaOptions? = nil,
    string: StringSchemaOptions? = nil
  ) -> Self {
    self.init(
      array: array,
      number: number,
      object: object,
      string: string
    )
  }
}
