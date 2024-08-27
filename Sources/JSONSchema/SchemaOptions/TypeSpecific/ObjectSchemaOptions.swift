public struct ObjectSchemaOptions: SchemaOptions {
  /// Key is the name of a property and each value is a schema used to validate that property.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#properties)
  public var properties: JSONValue?

  /// Key is a regular expression and each value is a schema use to validate that property.
  /// If a property name matches the given regular expression, the property value must validate against the corresponding schema.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#patternProperties)
  public var patternProperties: JSONValue?

  /// Used to control the handling of properties whose names are not listed in the `properties` keyword or match any of the regular expressions in the `patternProperties` keyword.
  /// By default any additional properties are allowed.
  /// If `.disabled`, no additional properties (not listed in `properties` or `patternProperties`) will be allowed.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#additionalproperties)
  public var additionalProperties: JSONValue?

  /// Similar to `additionalProperties` except that it can recognize properties declared in subschemas.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#unevaluatedproperties)
  public var unevaluatedProperties: JSONValue?

  /// List of property keywords that are required.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#required)
  public var required: JSONValue?

  /// Schema options to validate property names against.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#propertyNames)
  public var propertyNames: JSONValue?

  /// Minimum number of properties.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#size)
  public var minProperties: JSONValue?

  /// Maximum number of properties.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/object#size)
  public var maxProperties: JSONValue?

  /// Conditionally requires that certain properties must be present if a given property is present in an object.
  /// This should be an object, where each key is the property that may or may not be present in the instance
  /// and the value if an array of properties that should be present if the key is present instance.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/conditionals#dependentRequired)
  public var dependentRequired: JSONValue?

  init(
    properties: [String: Schema]? = nil,
    patternProperties: [String: Schema]? = nil,
    additionalProperties: SchemaControlOption? = nil,
    unevaluatedProperties: SchemaControlOption? = nil,
    required: [String]? = nil,
    propertyNames: StringSchemaOptions? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil,
    dependentRequired: [String: [String]]? = nil
  ) {
    let encoder = JSONValueEncoder()

    self.properties = properties.map { dictionary in
      .object(dictionary.compactMapValues { try? encoder.encode($0) })
    }
    self.patternProperties = patternProperties.map { dictionary in
      .object(dictionary.compactMapValues { try? encoder.encode($0) })
    }
    self.additionalProperties = additionalProperties.map { option in
      switch option {
      case .disabled:
        return .boolean(false)
      case .schema(let schema):
        return (try? encoder.encode(schema)) ?? .null
      }
    }
    self.unevaluatedProperties = unevaluatedProperties.map { option in
      switch option {
      case .disabled:
        return .boolean(false)
      case .schema(let schema):
        return (try? encoder.encode(schema)) ?? .null
      }
    }
    self.required = required.map { .array($0.map { JSONValue($0) }) }
    self.propertyNames = propertyNames.map { (try? encoder.encode($0)) ?? .null }
    self.minProperties = minProperties.map { JSONValue($0) }
    self.maxProperties = maxProperties.map { JSONValue($0) }
    self.dependentRequired = dependentRequired.map { dictionary in
      .object(dictionary.mapValues { JSONValue($0) })
    }
  }

  public static func options(
    properties: [String: Schema]? = nil,
    patternProperties: [String: Schema]? = nil,
    additionalProperties: SchemaControlOption? = nil,
    unevaluatedProperties: SchemaControlOption? = nil,
    required: [String]? = nil,
    propertyNames: StringSchemaOptions? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil,
    dependentRequired: [String: [String]]? = nil
  ) -> Self {
    self.init(
      properties: properties,
      patternProperties: patternProperties,
      additionalProperties: additionalProperties,
      unevaluatedProperties: unevaluatedProperties,
      required: required,
      propertyNames: propertyNames,
      minProperties: minProperties,
      maxProperties: maxProperties,
      dependentRequired: dependentRequired
    )
  }
}
