import JSONSchema

/// A JSON array type component for use in ``JSONSchemaBuilder``.
public struct JSONArray: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()
  var options: ArraySchemaOptions = .options()

  public var definition: Schema { .array(annotations, options) }

  public init() {}
}

extension JSONArray {
  /// Configure the items option schema.
  /// - Parameter items: A schema control option.
  /// - Returns: A new `JSONArray` with the items set.
  public func items(_ items: SchemaControlOption? = nil) -> Self {
    var copy = self
    copy.options.items = items
    return copy
  }

  /// Disallows array elements beyond what are provided in `prefixItems`.
  /// - Returns: A new `JSONArray` with the annotation added.
  public func disableItems() -> Self { self.items(.disabled) }

  /// Adds items to the schema.
  /// - Parameter items: A closure that returns a JSON schema representing the items.
  /// - Returns: A new `JSONArray` with the items set.
  public func items(@JSONSchemaBuilder _ items: () -> JSONSchemaComponent) -> Self {
    self.items(.schema(items().definition))
  }

  /// Adds prefix items to the schema.
  /// - Parameter prefixItems: An array of JSON schemas representing the prefix items.
  /// - Returns: A new `JSONArray` with the prefix items set.
  public func prefixItems(_ prefixItems: [Schema]?) -> Self {
    var copy = self
    copy.options.prefixItems = prefixItems
    return copy
  }

  /// Adds prefix items to the schema.
  /// - Parameter prefixItems: A closure that returns an array of JSON schemas representing the prefix items.
  /// - Returns: A new `JSONArray` with the prefix items set.
  public func prefixItems(@JSONSchemaBuilder _ prefixItems: () -> [JSONSchemaComponent]) -> Self {
    self.prefixItems(prefixItems().map(\.definition))
  }

  /// Adds unevaluated items to the schema.
  /// - Parameter unevaluatedItems: A schema control option.
  /// - Returns: A new `JSONArray` with the unevaluated items set.
  public func unevaluatedItems(_ unevaluatedItems: SchemaControlOption? = nil) -> Self {
    var copy = self
    copy.options.unevaluatedItems = unevaluatedItems
    return copy
  }

  /// Disables unevaluated items in the schema.
  /// - Returns: A new `JSONArray` with unevaluated items disabled.
  public func disableUnevaluatedItems() -> Self { self.unevaluatedItems(.disabled) }

  /// Adds unevaluated items to the schema.
  /// - Parameter unevaluatedItems: A closure that returns a JSON schema representing the unevaluated items.
  /// - Returns: A new `JSONArray` with the unevaluated items set.
  public func unevaluatedItems(
    @JSONSchemaBuilder _ unevaluatedItems: () -> JSONSchemaComponent
  ) -> Self { self.unevaluatedItems(.schema(unevaluatedItems().definition)) }

  /// Adds a `contains` schema to the schema.
  /// - Parameter contains: A JSON schema representing the `contains` schema.
  /// - Returns: A new `JSONArray` with the `contains` schema set.
  public func contains(_ contains: Schema?) -> Self {
    var copy = self
    copy.options.contains = contains
    return copy
  }

  /// Adds a `contains` schema to the schema.
  /// - Parameter contains: A closure that returns a JSON schema representing the `contains` schema.
  /// - Returns: A new `JSONArray` with the `contains` schema set.
  public func contains(@JSONSchemaBuilder _ contains: () -> JSONSchemaComponent) -> Self {
    self.contains(contains().definition)
  }

  /// Adds a minimum number of `contains` to the schema.
  /// - Parameter minContains: An integer representing the minimum number of `contains`.
  /// - Returns: A new `JSONArray` with the minimum number of `contains` set.
  public func minContains(_ minContains: Int?) -> Self {
    var copy = self
    copy.options.minContains = minContains
    return copy
  }

  /// Adds a maximum number of `contains` to the schema.
  /// - Parameter maxContains: An integer representing the maximum number of `contains`.
  /// - Returns: A new `JSONArray` with the maximum number of `contains` set.
  public func maxContains(_ maxContains: Int?) -> Self {
    var copy = self
    copy.options.maxContains = maxContains
    return copy
  }

  /// Adds a minimum number of items to the schema.
  /// - Parameter minItems: An integer representing the minimum number of items.
  /// - Returns: A new `JSONArray` with the minimum number of items set.
  public func minItems(_ minItems: Int?) -> Self {
    var copy = self
    copy.options.minItems = minItems
    return copy
  }

  /// Adds a maximum number of items to the schema.
  /// - Parameter maxItems: An integer representing the maximum number of items.
  /// - Returns: A new `JSONArray` with the maximum number of items set.
  public func maxItems(_ maxItems: Int?) -> Self {
    var copy = self
    copy.options.maxItems = maxItems
    return copy
  }

  /// Ensures that each item in the array is unique.
  /// - Returns: A new `JSONArray` with the unique items constraint set.
  public func uniqueItems(_ value: Bool = true) -> Self {
    var copy = self
    copy.options.uniqueItems = value
    return copy
  }
}
