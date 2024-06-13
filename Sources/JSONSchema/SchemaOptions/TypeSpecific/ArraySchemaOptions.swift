public struct ArraySchemaOptions: SchemaOptions, Equatable {
  /// Each element of the array must match the given schema.
  /// If `.disabled`, array elements beyond what are provided in `prefixItems` are not allowed.
  /// https://json-schema.org/understanding-json-schema/reference/array#items
  public let items: SchemaControlOption?

  /// Each item is a schema that corresponds to each index of the document's array. That is, an array where the first element validates the first element of the input array, the second element validates the second element of the input array, etc.
  /// https://json-schema.org/understanding-json-schema/reference/array#tupleValidation
  public let prefixItems: [Schema]?

  /// Applies to any values not evaluated by an `items`, `prefixItems`, or `contains` keyword.
  /// https://json-schema.org/understanding-json-schema/reference/array#unevaluateditems
  public let unevaluatedItems: SchemaControlOption?

  /// Specifies schema that must be valid against one or more items in the array.
  /// https://json-schema.org/understanding-json-schema/reference/array#contains
  public let contains: Schema?

  /// Used with `contains` to minimum number of times a schema matches a `contains` constraint.
  /// https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains
  public let minContains: Int?

  /// Used with `contains` to maximum number of times a schema matches a `contains` constraint.
  /// https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains
  public let maxContains: Int?

  /// Minimum number of items in the array.
  /// https://json-schema.org/understanding-json-schema/reference/array#length
  public let minItems: Int?

  /// Maximum number of items in the array.
  /// https://json-schema.org/understanding-json-schema/reference/array#length
  public let maxItems: Int?

  /// Ensure that each of the items in array is unique.
  /// https://json-schema.org/understanding-json-schema/reference/array#uniqueItems
  public let uniqueItems: Bool?

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
