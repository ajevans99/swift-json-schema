import JSONSchema

/// A JSON object schema component for use in ``JSONSchemaBuilder``.
public struct JSONObject: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()
  var options: ObjectSchemaOptions = .options()

  public var definition: Schema { .object(annotations, options) }

  public init() {}
}

extension JSONObject {
  /// Adds a property to the object schema.
  /// - Parameter property: A dictionary where the key is the property name and the value is the schema for the property.
  /// - Returns: A new `JSONObject` with the property set.
  public func properties(_ properties: [String: Schema]?) -> Self {
    var copy = self
    copy.options.properties = properties
    return copy
  }

  /// Defines the schema for the properties of the object.
  ///
  /// - SeeAlso: ``JSONProperty``
  /// - Parameter properties: The properties to add to the schema.
  /// - Returns: A new `JSONObject` with the properties set.
  public func properties(@JSONPropertySchemaBuilder _ properties: () -> [JSONProperty]) -> Self {
    self.properties(
      properties()
        .reduce(into: [:]) { partialResult, property in
          partialResult[property.key] = property.value.definition
        }
    )
  }

  /// Adds a property names schema to the object schema.
  /// - Parameter option: A dictionary where the key is the property name and the value is the schema for the property.
  /// - Returns: A new `JSONObject` with the property names set.
  public func patternProperties(_ patternProperties: [String: Schema]?) -> Self {
    var copy = self
    copy.options.patternProperties = patternProperties
    return copy
  }

  /// Adds a pattern properties schema to the object schema.
  /// - Parameter patternProperties: A closure that returns an array of JSON properties representing the pattern properties.
  /// - Returns: A new `JSONObject` with the pattern properties set.
  public func patternProperties(
    @JSONPropertySchemaBuilder _ patternProperties: () -> [JSONProperty]
  ) -> Self {
    self.patternProperties(
      patternProperties()
        .reduce(into: [:]) { partialResult, property in
          partialResult[property.key] = property.value.definition
        }
    )
  }

  /// Adds additional properties to the schema.
  /// - Parameter option: A schema control option.
  /// - Returns: A new `JSONObject` with the additional properties set.
  public func additionalProperties(_ addionalProperties: SchemaControlOption?) -> Self {
    var copy = self
    copy.options.additionalProperties = addionalProperties
    return copy
  }

  /// Disables additional properties in the schema.
  /// - Returns: A new `JSONObject` with additional properties disabled.
  public func disableAdditionalProperties() -> Self { self.additionalProperties(.disabled) }

  /// Adds additional properties to the schema.
  /// - Parameter additionalProperties: A closure that returns a JSON schema representing the additional properties.
  /// - Returns: A new `JSONObject` with the additional properties set.
  public func additionalProperties(
    @JSONSchemaBuilder _ additionalProperties: () -> JSONSchemaComponent
  ) -> Self { self.additionalProperties(.schema(additionalProperties().definition)) }

  /// Adds unevaluated properties to the schema.
  /// - Parameter unevaluatedProperties: A schema control option.
  /// - Returns: A new `JSONObject` with the unevaluated properties set.
  public func unevaluatedProperties(_ unevaluatedProperties: SchemaControlOption?) -> Self {
    var copy = self
    copy.options.unevaluatedProperties = unevaluatedProperties
    return copy
  }

  /// Disables unevaluated properties in the schema.
  /// - Returns: A new `JSONObject` with unevaluated properties disabled.
  public func disableUnevaluatedProperties() -> Self { self.unevaluatedProperties(.disabled) }

  /// Adds unevaluated properties to the schema.
  /// - Parameter content: A closure that returns a JSON schema representing the unevaluated properties.
  /// - Returns: A new `JSONObject` with the unevaluated properties set.
  public func unevaluatedProperties(@JSONSchemaBuilder _ content: () -> JSONSchemaComponent) -> Self
  { self.unevaluatedProperties(.schema(content().definition)) }

  /// Adds a required constraint to the schema.
  /// - Parameter properties: The properties that are required.
  /// - Returns: A new `JSONObject` with the required constraint set.
  public func required(_ properties: [String]?) -> Self {
    var copy = self
    copy.options.required = properties
    return copy
  }

  /// Adds a property names schema to the object schema.
  /// - Parameter option: A string schema option.
  /// - Returns: A new `JSONObject` with the property names set.
  public func propertyNames(_ option: StringSchemaOptions?) -> Self {
    var copy = self
    copy.options.propertyNames = option
    return copy
  }

  /// Adds a min properties constraint to the schema.
  /// - Parameter value: The minimum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the min properties constraint set.
  public func minProperties(_ value: Int?) -> Self {
    var copy = self
    copy.options.minProperties = value
    return copy
  }

  /// Adds a max properties constraint to the schema.
  /// - Parameter value: The maximum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the max properties constraint set.
  public func maxProperties(_ value: Int?) -> Self {
    var copy = self
    copy.options.maxProperties = value
    return copy
  }
}
