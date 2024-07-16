import JSONSchema

@attached(peer)
public macro ObjectOptions(
//  patternProperties: [String: Schema]? = nil,
//  additionalProperties: SchemaControlOption? = nil,
//  unevaluatedProperties: SchemaControlOption? = nil,
//  propertyNames: StringSchemaOptions? = nil,
  minProperties: Int? = nil,
  maxProperties: Int? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "ObjectOptionsMacro")
