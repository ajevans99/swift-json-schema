import JSONSchema

public struct JSONObject: JSONSchemaRepresentable {
  public var annotations: AnnotationOptions = .annotations()
  var options: ObjectSchemaOptions = .options()

  public var schema: Schema {
    .object(annotations, options)
  }

  public init() {}
}

public extension JSONObject {
  func properties(@JSONPropertySchemaBuilder _ properties: () -> [JSONProperty]) -> Self {
    var copy = self
    copy.options.properties = properties()
      .reduce(into: [:]) { partialResult, property in
        partialResult[property.key] = property.value.schema
      }
    return copy
  }

  func patternProperties(@JSONPropertySchemaBuilder _ patternProperties: () -> [JSONProperty]) -> Self {
    var copy = self
    copy.options.patternProperties = patternProperties()
      .reduce(into: [:]) { partialResult, property in
        partialResult[property.key] = property.value.schema
      }
    return copy
  }

  func disableAdditionalProperties() -> Self {
    var copy = self
    copy.options.additionalProperties = .disabled
    return copy
  }

  func additionalProperties(@JSONSchemaBuilder _ additionalProperties: () -> JSONSchemaRepresentable) -> Self {
    var copy = self
    copy.options.additionalProperties = .schema(additionalProperties().schema)
    return copy
  }

  func disableUnevaluatedProperties() -> Self {
    var copy = self
    copy.options.unevaluatedProperties = .disabled
    return copy
  }

  func unevaluatedProperties(@JSONSchemaBuilder _ content: () -> JSONSchemaRepresentable) -> Self {
    var copy = self
    copy.options.unevaluatedProperties = .schema(content().schema)
    return copy
  }

  func required(_ properties: [String]) -> Self {
    var copy = self
    copy.options.required = properties
    return copy
  }

  func propertyNames(_ option: StringSchemaOptions) -> Self {
    var copy = self
    copy.options.propertyNames = option
    return copy
  }

  func minProperties(_ value: Int) -> Self {
    var copy = self
    copy.options.minProperties = value
    return copy
  }

  func maxProperties(_ value: Int) -> Self {
    var copy = self
    copy.options.maxProperties = value
    return copy
  }
}
