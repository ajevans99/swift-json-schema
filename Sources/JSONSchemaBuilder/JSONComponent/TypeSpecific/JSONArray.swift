import JSONSchema

/// A JSON array type component for use in ``JSONSchemaBuilder``.
public struct JSONArray<Items: JSONSchemaComponent>: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()
  var options: ArraySchemaOptions

  public var definition: Schema { .array(annotations, options) }

  let items: Items

  /// Creates a new JSON array schema component.
  /// - Parameter items: A JSON schema component for validating each item in the array.
  public init(@JSONSchemaBuilder items: () -> Items) {
    self.items = items()
    self.options = .options(items: .schema(self.items.definition))
  }

  /// Creates a new JSON array schema component.
  /// - Parameter disableItems: A boolean value that disallows items in the array.
  public init(disableItems: Bool = false) where Items == JSONAnyValue {
    self.items = JSONAnyValue()
    self.options = disableItems ? .options(items: .disabled) : .options()
  }

  public func validate(_ value: JSONValue, against validator: Validator) -> Validation<[Items.Output]> {
    if case .array(let array) = value {
      let builder = ValidationErrorBuilder()
      builder.addErrors(validator.validate(array: array, against: options).invalid)

      var outputs: [Items.Output] = []
      for item in array {
        switch items.validate(item, against: validator) {
        case .valid(let value): outputs.append(value)
        case .invalid(let e): builder.addErrors(e)
        }
      }

      return builder.build(for: outputs)
    }
    return .error(.typeMismatch(expected: .array, actual: value))
  }
}

extension JSONArray {
  /// Each item is a schema that corresponds to each index of the document's array. That is, an array where the first element validates the first element of the input array, the second element validates the second element of the input array, etc.
  /// - Parameter prefixItems: An array of JSON schemas representing the prefix items.
  /// - Returns: A new `JSONArray` with the prefix items set.
  public func prefixItems(_ prefixItems: [Schema]?) -> Self {
    var copy = self
    copy.options.prefixItems = prefixItems.map { JSONValue($0) }
    return copy
  }

  /// Each item is a schema that corresponds to each index of the document's array. That is, an array where the first element validates the first element of the input array, the second element validates the second element of the input array, etc.
  /// - Parameter prefixItems: A closure that returns an array of JSON schemas representing the prefix items.
  /// - Returns: A new `JSONArray` with the prefix items set.
  public func prefixItems(
    @JSONSchemaCollectionBuilder<JSONValue> _ prefixItems: () -> [JSONComponents.AnyComponent<
      JSONValue
    >]
  ) -> Self { self.prefixItems(prefixItems().map(\.definition)) }

  /// Schema options applied to any values not evaluated by an `items`, `prefixItems`, or `contains` keyword.
  /// - Parameter unevaluatedItems: A schema control option.
  /// - Returns: A new `JSONArray` with the unevaluated items set.
  public func unevaluatedItems(_ unevaluatedItems: SchemaControlOption? = nil) -> Self {
    var copy = self
    copy.options.unevaluatedItems = unevaluatedItems.map { JSONValue($0) }
    return copy
  }

  /// Disables any values not evaluated by an `items`, `prefix`, or `contains` keyword.
  /// - Returns: A new `JSONArray` with unevaluated items disabled.
  public func disableUnevaluatedItems() -> Self { self.unevaluatedItems(.disabled) }

  /// Schema options applied to any values not evaluated by an `items`, `prefixItems`, or `contains` keyword.
  /// - Parameter unevaluatedItems: A closure that returns a JSON schema representing the unevaluated items.
  /// - Returns: A new `JSONArray` with the unevaluated items set.
  public func unevaluatedItems<Component: JSONSchemaComponent>(
    @JSONSchemaBuilder _ unevaluatedItems: () -> Component
  ) -> Self { self.unevaluatedItems(.schema(unevaluatedItems().definition)) }

  /// Specifies schema that must be valid against one or more items in the array.
  /// - Parameter contains: A JSON schema representing the `contains` schema.
  /// - Returns: A new `JSONArray` with the `contains` schema set.
  public func contains(_ contains: Schema?) -> Self {
    var copy = self
    copy.options.contains = contains.map { JSONValue($0) }
    return copy
  }

  /// Adds a `contains` schema to the schema.
  /// - Parameter contains: A closure that returns a JSON schema representing the `contains` schema.
  /// - Returns: A new `JSONArray` with the `contains` schema set.
  public func contains(@JSONSchemaBuilder _ contains: () -> any JSONSchemaComponent) -> Self {
    self.contains(contains().definition)
  }

  /// Used with `contains` to minimum number of times a schema matches a `contains` constraint.
  /// - Parameter minContains: An integer representing the minimum number of `contains`.
  /// - Returns: A new `JSONArray` with the minimum number of `contains` set.
  public func minContains(_ minContains: Int?) -> Self {
    var copy = self
    copy.options.minContains = minContains.map { JSONValue($0) }
    return copy
  }

  /// Used with `contains` to maximum number of times a schema matches a `contains` constraint.
  /// - Parameter maxContains: An integer representing the maximum number of `contains`.
  /// - Returns: A new `JSONArray` with the maximum number of `contains` set.
  public func maxContains(_ maxContains: Int?) -> Self {
    var copy = self
    copy.options.maxContains = maxContains.map { JSONValue($0) }
    return copy
  }

  /// Adds a minimum number of items to the schema.
  /// - Parameter minItems: An integer representing the minimum number of items.
  /// - Returns: A new `JSONArray` with the minimum number of items set.
  public func minItems(_ minItems: Int?) -> Self {
    var copy = self
    copy.options.minItems = minItems.map { JSONValue($0) }
    return copy
  }

  /// Adds a maximum number of items to the schema.
  /// - Parameter maxItems: An integer representing the maximum number of items.
  /// - Returns: A new `JSONArray` with the maximum number of items set.
  public func maxItems(_ maxItems: Int?) -> Self {
    var copy = self
    copy.options.maxItems = maxItems.map { JSONValue($0) }
    return copy
  }

  /// Ensures that each item in the array is unique.
  /// - Returns: A new `JSONArray` with the unique items constraint set.
  public func uniqueItems(_ value: Bool? = true) -> Self {
    var copy = self
    copy.options.uniqueItems = value.map { JSONValue($0) }
    return copy
  }
}
