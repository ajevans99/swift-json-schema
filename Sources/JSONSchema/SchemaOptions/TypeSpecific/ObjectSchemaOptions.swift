public struct ObjectSchemaOptions: SchemaOptions {
  /// Key is the name of a property and each value is a schema used to validate that property.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#properties)
  public let properties: [String: Schema]?

  /// Key is a regular expression and each value is a schema use to validate that property.
  /// If a property name matches the given regular expression, the property value must validate against the corresponding schema.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#patternProperties)
  public let patternProperties: [String: Schema]?

  /// Used to control the handling of properties whose names are not listed in the `properties` keyword or match any of the regular expressions in the `patternProperties` keyword.
  /// By default any additional properties are allowed.
  /// If `.disabled`, no additional properties (not listed in `properties` or `patternProperties`) will be allowed.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#additionalproperties)
  public let additionalProperties: SchemaControlOption?

  /// Similar to `additionalProperties` except that it can recognize properties declared in subschemas.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#unevaluatedproperties)
  public let unevaluatedProperties: SchemaControlOption?

  /// List of property keywords that are required.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#required)
  public let required: [String]?

  /// Schema options to validate property names against.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#propertyNames)
  public let propertyNames: StringSchemaOptions?

  /// Minimum number of properties.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#size)
  public let minProperties: Int?

  /// Maximum number of properties.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#size)
  public let maxProperties: Int?

  init(
    properties: [String: Schema]? = nil,
    patternProperties: [String: Schema]? = nil,
    additionalProperties: SchemaControlOption? = nil,
    unevaluatedProperties: SchemaControlOption? = nil,
    required: [String]? = nil,
    propertyNames: StringSchemaOptions? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil
  ) {
    self.properties = properties
    self.patternProperties = patternProperties
    self.additionalProperties = additionalProperties
    self.unevaluatedProperties = unevaluatedProperties
    self.required = required
    self.propertyNames = propertyNames
    self.minProperties = minProperties
    self.maxProperties = maxProperties
  }

  public static func options(
    properties: [String: Schema]? = nil,
    patternProperties: [String: Schema]? = nil,
    additionalProperties: SchemaControlOption? = nil,
    unevaluatedProperties: SchemaControlOption? = nil,
    required: [String]? = nil,
    propertyNames: StringSchemaOptions? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil
  ) -> Self {
    self.init(
      properties: properties,
      patternProperties: patternProperties,
      additionalProperties: additionalProperties,
      unevaluatedProperties: unevaluatedProperties,
      required: required,
      propertyNames: propertyNames,
      minProperties: minProperties,
      maxProperties: maxProperties
    )
  }
}
