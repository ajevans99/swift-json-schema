import JSONSchema

public struct JSONArray: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()
  var options: ArraySchemaOptions = .options()

  public var schema: Schema {
    .array(annotations, options)
  }

  public init() {}
}

public extension JSONArray {
  func disableItems() -> Self {
    var copy = self
    copy.options.items = .disabled
    return copy
  }

  func items(@JSONSchemaBuilder _ items: () -> JSONSchemaRepresentable) -> Self {
    var copy = self
    copy.options.items = .schema(items().schema)
    return copy
  }

  func prefixItems(@JSONSchemaBuilder _ prefixItems: () -> [JSONSchemaRepresentable]) -> Self {
    var copy = self
    copy.options.prefixItems = prefixItems().map(\.schema)
    return copy
  }

  func disableUnevaluatedItems() -> Self {
    var copy = self
    copy.options.unevaluatedItems = .disabled
    return copy
  }

  func unevaluatedItems(@JSONSchemaBuilder _ unevaluatedItems: () -> JSONSchemaRepresentable) -> Self {
    var copy = self
    copy.options.unevaluatedItems = .schema(unevaluatedItems().schema)
    return copy
  }

  func contains(@JSONSchemaBuilder _ contains: () -> JSONSchemaRepresentable) -> Self {
    var copy = self
    copy.options.contains = contains().schema
    return copy
  }

  func minContains(_ minContains: Int) -> Self {
    var copy = self
    copy.options.minContains = minContains
    return copy
  }

  func maxContains(_ maxContains: Int) -> Self {
    var copy = self
    copy.options.maxContains = maxContains
    return copy
  }

  func minItems(_ minItems: Int) -> Self {
    var copy = self
    copy.options.minItems = minItems
    return copy
  }

  func maxItems(_ maxItems: Int) -> Self {
    var copy = self
    copy.options.maxItems = maxItems
    return copy
  }

  func uniqueItems() -> Self {
    var copy = self
    copy.options.uniqueItems = true
    return copy
  }
}
