public struct ArraySchemaOptions: SchemaOptions, Equatable {
  /// Each element of the array must match the given schema.
  /// If `.disabled`, array elements beyond what are provided in `prefixItems` are not allowed.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#items)
  public var items: SchemaControlOption?

  /// Each item is a schema that corresponds to each index of the document's array. That is, an array where the first element validates the first element of the input array, the second element validates the second element of the input array, etc.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#tupleValidation)
  public var prefixItems: [Schema]?

  /// Applies to any values not evaluated by an `items`, `prefixItems`, or `contains` keyword.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#unevaluateditems)
  public var unevaluatedItems: SchemaControlOption?

  /// Specifies schema that must be valid against one or more items in the array.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#contains)
  public var contains: Schema?

  /// Used with `contains` to minimum number of times a schema matches a `contains` constraint.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains)
  public var minContains: Int?

  /// Used with `contains` to maximum number of times a schema matches a `contains` constraint.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains)
  public var maxContains: Int?

  /// Minimum number of items in the array.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#length)
  public var minItems: Int?

  /// Maximum number of items in the array.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#length)
  public var maxItems: Int?

  /// Ensure that each of the items in array is unique.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/array#uniqueItems)
  public var uniqueItems: Bool?

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
    self.items = items
    self.prefixItems = prefixItems
    self.unevaluatedItems = unevaluatedItems
    self.contains = contains
    self.minContains = minContains
    self.maxContains = maxContains
    self.minItems = minItems
    self.maxItems = maxItems
    self.uniqueItems = uniqueItems
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
