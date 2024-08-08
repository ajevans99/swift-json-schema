import JSONSchema

@attached(peer) public macro ObjectOptions(
  propertyNames: StringSchemaOptions? = nil,
  minProperties: Int? = nil,
  maxProperties: Int? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "ObjectOptionsMacro")
