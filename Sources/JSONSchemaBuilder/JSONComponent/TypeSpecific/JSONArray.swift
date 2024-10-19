import JSONSchema

/// A JSON array type component for use in ``JSONSchemaBuilder``.
public struct JSONArray<T: JSONSchemaComponent>: JSONSchemaComponent {
  public var schemaValue = [KeywordIdentifier: JSONValue]()

  let items: T

  /// Creates a new JSON array schema component.
  /// - Parameter items: A JSON schema component for validating each item in the array.
  public init(@JSONSchemaBuilder items: () -> T) {
    self.items = items()
    schemaValue[Keywords.TypeKeyword.name] = .string(JSONType.array.rawValue)
    schemaValue[Keywords.Items.name] = .object(self.items.schemaValue)
  }

  /// Creates a new JSON array schema component.
  /// - Parameter disableItems: A boolean value that disallows items in the array.
  public init(disableItems: Bool = false) where T == JSONAnyValue {
    self.init {
      JSONAnyValue()
    }
  }

  public func schema() -> Schema {
    fatalError("TODO: Implement")
  }

  public func validate(_ value: JSONValue) -> Validated<[T.Output], String> {
    if case .array(let array) = value {
      var outputs: [T.Output] = []
      var errors: [String] = []
      for item in array {
        switch items.validate(item) {
        case .valid(let value): outputs.append(value)
        case .invalid(let e): errors.append(contentsOf: e)
        }
      }
      guard !errors.isEmpty else { return .valid(outputs) }
      return .invalid(errors)
    }
    return .error("Expected array value")
  }
}

extension JSONArray {
  /// Each item is a schema that corresponds to each index of the document's array. That is, an array where the first element validates the first element of the input array, the second element validates the second element of the input array, etc.
  /// - Parameter prefixItems: A closure that returns an array of JSON schemas representing the prefix items.
  /// - Returns: A new `JSONArray` with the prefix items set.
  public func prefixItems(
    @JSONSchemaCollectionBuilder<JSONValue> _ prefixItems: () -> [JSONComponents.AnyComponent<
      JSONValue
    >]
  ) -> Self {
    var copy = self
    copy.schemaValue[Keywords.PrefixItems.name] = .array(prefixItems().map { .object($0.schemaValue) })
    return copy
  }

  /// Schema options applied to any values not evaluated by an `items`, `prefixItems`, or `contains` keyword.
  /// - Parameter unevaluatedItems: A closure that returns a JSON schema representing the unevaluated items.
  /// - Returns: A new `JSONArray` with the unevaluated items set.
  public func unevaluatedItems<Component: JSONSchemaComponent>(
    @JSONSchemaBuilder _ unevaluatedItems: () -> Component
  ) -> Self {
    var copy = self
    copy.schemaValue[Keywords.UnevaluatedItems.name] = .object(unevaluatedItems().schemaValue)
    return copy
  }

  /// Adds a `contains` schema to the schema.
  /// - Parameter contains: A closure that returns a JSON schema representing the `contains` schema.
  /// - Returns: A new `JSONArray` with the `contains` schema set.
  public func contains(@JSONSchemaBuilder _ contains: () -> any JSONSchemaComponent) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Contains.name] = .object(contains().schemaValue)
    return copy
  }

  /// Used with `contains` to minimum number of times a schema matches a `contains` constraint.
  /// - Parameter minContains: An integer representing the minimum number of `contains`.
  /// - Returns: A new `JSONArray` with the minimum number of `contains` set.
  public func minContains(_ minContains: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MinContains.name] = .integer(minContains)
    return copy
  }

  /// Used with `contains` to maximum number of times a schema matches a `contains` constraint.
  /// - Parameter maxContains: An integer representing the maximum number of `contains`.
  /// - Returns: A new `JSONArray` with the maximum number of `contains` set.
  public func maxContains(_ maxContains: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MaxContains.name] = .integer(maxContains)
    return copy
  }

  /// Adds a minimum number of items to the schema.
  /// - Parameter minItems: An integer representing the minimum number of items.
  /// - Returns: A new `JSONArray` with the minimum number of items set.
  public func minItems(_ minItems: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MinItems.name] = .integer(minItems)
    return copy
  }

  /// Adds a maximum number of items to the schema.
  /// - Parameter maxItems: An integer representing the maximum number of items.
  /// - Returns: A new `JSONArray` with the maximum number of items set.
  public func maxItems(_ maxItems: Int) -> Self {
    var copy = self
    copy.schemaValue[Keywords.MaxItems.name] = .integer(maxItems)
    return copy
  }

  /// Ensures that each item in the array is unique.
  /// - Returns: A new `JSONArray` with the unique items constraint set.
  public func uniqueItems(_ value: Bool = true) -> Self {
    var copy = self
    copy.schemaValue[Keywords.UniqueItems.name] = .boolean(value)
    return copy
  }
}
