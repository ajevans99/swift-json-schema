import JSONSchema

/// A JSON array type component for use in ``JSONSchemaBuilder``.
public struct JSONArray<T: JSONSchemaComponent>: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()
  var options: ArraySchemaOptions

  public var definition: Schema { .array(annotations, options) }

  let items: T

  public init(@JSONSchemaBuilder items: () -> T) {
    self.items = items()
    self.options = .options(items: .schema(self.items.definition))
  }

  public init(disableItems: Bool = false) where T == JSONAnyValue {
    self.items = JSONAnyValue()
    self.options = disableItems ? .options(items: .disabled) : .options()
  }

  public func validate(_ value: JSONValue) -> Validated<[T.Output], String> {
    if case .array = value {
      return .error("Not yet implemented")
    }
    return .error("Expected array value")
  }
}

extension JSONArray {
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
  public func prefixItems<each Component: JSONSchemaComponent>(@JSONSchemaBuilder _ prefixItems: () -> SchemaTuple<repeat each Component>) -> Self {
    var definitions = [Schema]()
#if swift(>=6)
    for component in repeat each prefixItems().component {
      definitions.append(component.definition)
    }
#else
    func appendDefinition<Comp: JSONSchemaComponent>(_ component: Comp) {
      definitions.append(component.definition)
    }
    let components = prefixItems().component
    repeat appendDefinition(each components)
#endif
    return self.prefixItems(definitions)
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
  public func unevaluatedItems<Component: JSONSchemaComponent>(
    @JSONSchemaBuilder _ unevaluatedItems: () -> Component
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
  public func contains(@JSONSchemaBuilder _ contains: () -> any JSONSchemaComponent) -> Self {
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
