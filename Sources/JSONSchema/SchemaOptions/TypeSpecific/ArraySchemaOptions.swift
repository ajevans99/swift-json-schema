public struct ArraySchemaOptions: SchemaOptions, Equatable {
  /// Each element of the array must match the given schema.
  /// If `.disabled`, array elements beyond what are provided in `prefixItems` are not allowed.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#items)
  public var items: JSONValue?

  /// Each item is a schema that corresponds to each index of the document's array. That is, an array where the first element validates the first element of the input array, the second element validates the second element of the input array, etc.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#tupleValidation)
  public var prefixItems: JSONValue?

  /// Applies to any values not evaluated by an `items`, `prefixItems`, or `contains` keyword.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#unevaluateditems)
  public var unevaluatedItems: JSONValue?

  /// Specifies schema that must be valid against one or more items in the array.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#contains)
  public var contains: JSONValue?

  /// Used with `contains` to minimum number of times a schema matches a `contains` constraint.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains)
  public var minContains: JSONValue?

  /// Used with `contains` to maximum number of times a schema matches a `contains` constraint.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains)
  public var maxContains: JSONValue?

  /// Minimum number of items in the array.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#length)
  public var minItems: JSONValue?

  /// Maximum number of items in the array.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#length)
  public var maxItems: JSONValue?

  /// Ensure that each of the items in array is unique.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#uniqueItems)
  public var uniqueItems: JSONValue?

  init(
    items: SchemaControlOption? = nil,
    prefixItems: [Schema]? = nil,
    unevaluatedItems: SchemaControlOption? = nil,
    contains: Schema? = nil,
    minContains: Int? = nil,
    maxContains: Int? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil
  ) {
    let encoder = JSONValueEncoder()
    self.items = items.map { JSONValue($0, encoder: encoder) }
    self.prefixItems = prefixItems.map { JSONValue($0, encoder: encoder) }
    self.unevaluatedItems = unevaluatedItems.map { JSONValue($0, encoder: encoder) }
    self.contains = contains.map { JSONValue($0, encoder: encoder) }
    self.minContains = minContains.map { JSONValue($0) }
    self.maxContains = maxContains.map { JSONValue($0) }
    self.minItems = minItems.map { JSONValue($0) }
    self.maxItems = maxItems.map { JSONValue($0) }
    self.uniqueItems = uniqueItems.map { JSONValue($0) }
  }

  public static func options(
    items: SchemaControlOption? = nil,
    prefixItems: [Schema]? = nil,
    unevaluatedItems: SchemaControlOption? = nil,
    contains: Schema? = nil,
    minContains: Int? = nil,
    maxContains: Int? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil
  ) -> Self {
    self.init(
      items: items,
      prefixItems: prefixItems,
      unevaluatedItems: unevaluatedItems,
      contains: contains,
      minContains: minContains,
      maxContains: maxContains,
      minItems: minItems,
      maxItems: maxItems,
      uniqueItems: uniqueItems
    )
  }
}
