import JSONSchema

/// A JSON object schema component for use in ``JSONSchemaBuilder``.
public struct JSONObject<Props: PropertyCollection>: JSONSchemaComponent {
  public var schemaValue = [KeywordIdentifier: JSONValue]()

  let properties: Props

  /// Constructs a new `JSONObject` with the provided properties.
  ///
  /// Example:
  /// ```swift
  /// let schema = JSONObject {
  ///   JSONProperty(key: "name", value: JSONString())
  /// }
  /// ```
  /// - Parameter properties: A closure that returns an collection of `JSONProperty` instances.
  public init(@JSONPropertySchemaBuilder with properties: () -> Props) {
    let properties = properties()
    self.properties = properties

    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.object.rawValue)
    if !properties.requiredKeys.isEmpty {
      schemaValue[Keywords.Required.name] = .array(properties.requiredKeys.map { .string($0) })
    }
    if !properties.schemaValue.isEmpty {
      schemaValue[Keywords.Properties.name] = .object(properties.schemaValue)
    }
  }

  /// Creates a new `JSONObject` with no property requirements.
  public init() where Props == EmptyPropertyCollection { self.init(with: {}) }

  public func schema() -> Schema {
    ObjectSchema(
      schemaValue: schemaValue,
      location: .init(),
      context: .init(dialect: .draft2020_12)
    )
    .asSchema()
  }

  public func parse(_ input: JSONValue) -> Validated<Props.Output, String> {
    if case .object(let dictionary) = input { return properties.validate(dictionary) }
    return .error("Not an object")
  }
}

extension JSONObject {
  /// Adds a pattern properties schema to the object schema.
  /// - Parameter patternProperties: A closure that returns an array of JSON properties representing the pattern properties.
  /// - Returns: A new `JSONObject` with the pattern properties set.
  public func patternProperties<Pattern: PropertyCollection>(
    @JSONPropertySchemaBuilder _ patternProperties: () -> Pattern
  ) -> Self {
    var copy = self
    copy.schemaValue[Keywords.PatternProperties.name] = .object(patternProperties().schemaValue)
    return copy
  }

  /// Adds additional properties to the schema and modifies validation output to include any additional properties as part of the tuple.
  ///
  /// Note that using this on an empty object with ``JSONObject/init()`` will cause the validated output to include `Void`. For example,
  /// ```swift
  /// let myObj = JSONObject()
  ///   .additionalProperties {
  ///     JSONString()
  ///   }
  /// ```
  /// `myObj.validate(/* some input */)` will have a type of `Validated<(Void, String), String>`
  ///
  /// For now, to drop the `Void`, you can add a map, like `.map { $1 }`.
  /// TODO: Drop `Void` values from tuple with builder.
  ///
  /// - Parameter additionalProperties: A closure that returns a JSON schema representing the additional properties.
  /// - Returns: A new compoment with the additional properties set and validation modified.
  public func additionalProperties<C: JSONSchemaComponent>(
    @JSONSchemaBuilder _ additionalProperties: () -> C
  ) -> JSONComponents.AdditionalProperties<Props, C> {
    JSONComponents.AdditionalProperties(
      base: self,
      additionalProperties: additionalProperties()
    )
  }

  /// Adds unevaluated properties to the schema.
  /// - Parameter content: A closure that returns a JSON schema representing the unevaluated properties.
  /// - Returns: A new `JSONObject` with the unevaluated properties set.
  public func unevaluatedProperties<C: JSONSchemaComponent>(
    @JSONSchemaBuilder _ content: () -> C
  ) -> Self {
    var copy = self
    copy.schemaValue[Keywords.UnevaluatedProperties.name] = .object(content().schemaValue)
    return copy
  }

  /// Adds schema options to validate property names against.
  /// The content should be a ``JSONString`` to produce a valid schema.
  /// - Parameter content: A string schema component.
  /// - Returns: A new `JSONObject` with the property names set.
  public func propertyNames<C: JSONSchemaComponent>(
    @JSONSchemaBuilder _ content: () -> C
  ) -> Self {
    var copy = self
    copy.schemaValue[Keywords.PropertyNames.name] = .object(content().schemaValue)
    return copy
  }

  /// Adds a minimum number of properties constraint to the schema.
  /// - Parameter value: The minimum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the min properties constraint set.
  public func minProperties(_ value: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MinProperties.name] = .integer(value)
    return copy
  }

  /// Adds a maximum number of properties constraint to the schema.
  /// - Parameter value: The maximum number of properties that the object must have.
  /// - Returns: A new `JSONObject` with the max properties constraint set.
  public func maxProperties(_ value: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MaxProperties.name] = .integer(value)
    return copy
  }
}
