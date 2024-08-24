import JSONSchema

/// A JSON object schema component for use in ``JSONSchemaBuilder``.
public struct JSONObject<Props: PropertyCollection>: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()
  var options: ObjectSchemaOptions

  public var definition: Schema { .object(annotations, options) }

  let properties: Props

  /// Constructs a new `JSONObject` with the provided properties.
  ///
  /// Example:
  /// ```swift
  /// let schema = JSONObject {
  ///   JSONProperty(key: "name", value: JSONString())
  /// }
  /// ```
  /// - Parameter build: A closure that returns an collection of `JSONProperty` instances.
  public init(@JSONPropertySchemaBuilder with build: () -> Props) {
    annotations = .annotations()
    properties = build()
    options = .options(
      properties: properties.schema.nilIfEmpty,
      required: properties.requiredKeys.nilIfEmpty
    )
  }

  /// Creates a new `JSONObject` with no property requirements.
  public init() where Props == EmptyPropertyCollection { self.init(with: {}) }

  public func validate(_ value: JSONValue, against validator: Validator) -> Validation<Props.Output> {
    if case .object(let dictionary) = value {
//      validator.validate(dictionary, against: options)
      return properties.validate(dictionary, against: validator)
    }
    return .error(.typeMismatch(expected: .object, actual: value))
  }
}

extension JSONObject {
  /// Adds pattern properties to the object schema.
  /// - Parameter patternProperties: A dictionary where the key is the property name as a regular expression and the value is the schema.
  /// - Returns: A new `JSONObject` with the property names set.
  public func patternProperties(_ patternProperties: [String: Schema]?) -> Self {
    var copy = self
    copy.options.patternProperties = patternProperties
    return copy
  }

  /// Adds a pattern properties schema to the object schema.
  /// - Parameter patternProperties: A closure that returns an array of JSON properties representing the pattern properties.
  /// - Returns: A new `JSONObject` with the pattern properties set.
  public func patternProperties<Pattern: PropertyCollection>(
    @JSONPropertySchemaBuilder _ patternProperties: () -> Pattern
  ) -> Self { self.patternProperties(patternProperties().schema) }

  /// Adds additional properties to the schema.
  /// - Parameter addionalProperties: A schema control option.
  /// - Returns: A new `JSONObject` with the additional properties set.
  public func additionalProperties(_ addionalProperties: SchemaControlOption?) -> Self {
    var copy = self
    copy.options.additionalProperties = addionalProperties
    return copy
  }

  /// Disables additional properties in the schema.
  /// - Returns: A new `JSONObject` with additional properties disabled.
  public func disableAdditionalProperties() -> Self { self.additionalProperties(.disabled) }

  /// Adds additional properties to the schema and modifies validation output to include any additional properties as part of the tuple.
  ///
  /// Note that using this on an empty object with ``JSONObject/init()`` will cause the validated output to include `Void`. For example,
  /// ```swift
  /// let myObj = JSONObject()
  ///   .additionalProperties {
  ///     JSONString()
  ///   }
  /// ```
  /// `myObj.validate(/* some input */)` will have a type of `Validation<(Void, String)>`
  ///
  /// For now, to drop the `Void`, you can add a map, like `.map { $1 }`.
  /// TODO: Drop `Void` values from tuple with builder.
  ///
  /// - Parameter additionalProperties: A closure that returns a JSON schema representing the additional properties.
  /// - Returns: A new compoment with the additional properties set and validation modified.
  public func additionalProperties<C: JSONSchemaComponent>(
    @JSONSchemaBuilder _ additionalProperties: () -> C
  ) -> JSONComponents.AdditionalProperties<Props, C> {
    let additionalPropertiesSchema = additionalProperties()
    return JSONComponents.AdditionalProperties(
      base: self,
      additionalProperties: additionalPropertiesSchema
    )
  }

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
  public func unevaluatedProperties<C: JSONSchemaComponent>(
    @JSONSchemaBuilder _ content: () -> C
  ) -> Self { self.unevaluatedProperties(.schema(content().definition)) }

  /// Adds schema options to validate property names against.
  /// - Parameter option: A string schema option.
  /// - Returns: A new `JSONObject` with the property names set.
  public func propertyNames(_ option: StringSchemaOptions?) -> Self {
    var copy = self
    copy.options.propertyNames = option
    return copy
  }

  /// Adds a minimum number of properties constraint to the schema.
  /// - Parameter value: The minimum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the min properties constraint set.
  public func minProperties(_ value: Int?) -> Self {
    var copy = self
    copy.options.minProperties = value
    return copy
  }

  /// Adds a maximum number of properties constraint to the schema.
  /// - Parameter value: The maximum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the max properties constraint set.
  public func maxProperties(_ value: Int?) -> Self {
    var copy = self
    copy.options.maxProperties = value
    return copy
  }
}
