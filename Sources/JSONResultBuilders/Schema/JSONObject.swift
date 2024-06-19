import JSONSchema

/// A JSON object schema component for use in ``JSONSchemaBuilder``.
public struct JSONObject: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()
  var options: ObjectSchemaOptions = .options()

  public var schema: Schema { .object(annotations, options) }

  public init() {}
}

extension JSONObject {
  /// Defines the schema for the properties of the object.
  /// 
  /// - SeeAlso: ``JSONProperty``
  /// - Parameter properties: The properties to add to the schema.
  /// - Returns: A new `JSONObject` with the properties set.
  public func properties(@JSONPropertySchemaBuilder _ properties: () -> [JSONProperty]) -> Self {
    var copy = self
    copy.options.properties = properties()
      .reduce(into: [:]) { partialResult, property in
        partialResult[property.key] = property.value.schema
      }
    return copy
  }

  /// Adds a pattern properties schema to the object schema.
  /// - Parameter patternProperties: A closure that returns an array of JSON properties representing the pattern properties.
  /// - Returns: A new `JSONObject` with the pattern properties set.
  public func patternProperties(
    @JSONPropertySchemaBuilder _ patternProperties: () -> [JSONProperty]
  ) -> Self {
    var copy = self
    copy.options.patternProperties = patternProperties()
      .reduce(into: [:]) { partialResult, property in
        partialResult[property.key] = property.value.schema
      }
    return copy
  }

  /// Disables additional properties in the schema.
  /// - Returns: A new `JSONObject` with additional properties disabled.
  public func disableAdditionalProperties() -> Self {
    var copy = self
    copy.options.additionalProperties = .disabled
    return copy
  }

  /// Adds additional properties to the schema.
  /// - Parameter additionalProperties: A closure that returns a JSON schema representing the additional properties.
  /// - Returns: A new `JSONObject` with the additional properties set.
  public func additionalProperties(
    @JSONSchemaBuilder _ additionalProperties: () -> JSONSchemaRepresentable
  ) -> Self {
    var copy = self
    copy.options.additionalProperties = .schema(additionalProperties().schema)
    return copy
  }

  /// Disables unevaluated properties in the schema.
  /// - Returns: A new `JSONObject` with unevaluated properties disabled.
  public func disableUnevaluatedProperties() -> Self {
    var copy = self
    copy.options.unevaluatedProperties = .disabled
    return copy
  }

  /// Adds unevaluated properties to the schema.
  /// - Parameter content: A closure that returns a JSON schema representing the unevaluated properties.
  /// - Returns: A new `JSONObject` with the unevaluated properties set.
  public func unevaluatedProperties(
    @JSONSchemaBuilder _ content: () -> JSONSchemaRepresentable
  ) -> Self {
    var copy = self
    copy.options.unevaluatedProperties = .schema(content().schema)
    return copy
  }

  /// Adds a required constraint to the schema.
  /// - Parameter properties: The properties that are required.
  /// - Returns: A new `JSONObject` with the required constraint set.
  public func required(_ properties: [String]) -> Self {
    var copy = self
    copy.options.required = properties
    return copy
  }

  /// Adds a property names schema to the object schema.
  /// - Parameter option: A string schema option.
  /// - Returns: A new `JSONObject` with the property names set.
  public func propertyNames(_ option: StringSchemaOptions) -> Self {
    var copy = self
    copy.options.propertyNames = option
    return copy
  }

  /// Adds a min properties constraint to the schema.
  /// - Parameter value: The minimum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the min properties constraint set.
  public func minProperties(_ value: Int) -> Self {
    var copy = self
    copy.options.minProperties = value
    return copy
  }

  /// Adds a max properties constraint to the schema.
  /// - Parameter value: The maximum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the max properties constraint set.
  public func maxProperties(_ value: Int) -> Self {
    var copy = self
    copy.options.maxProperties = value
    return copy
  }
}
