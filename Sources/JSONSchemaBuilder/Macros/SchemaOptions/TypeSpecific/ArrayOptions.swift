import JSONSchema

@attached(peer)
public macro ArrayOptions(
//  prefixItems: [Schema]? = nil,
//  unevaluatedItems: SchemaControlOption? = nil,
//  contains: Schema? = nil,
  minContains: Int? = nil,
  maxContains: Int? = nil,
  minItems: Int? = nil,
  maxItems: Int? = nil,
  uniqueItems: Bool? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "ArrayOptionsMacro")
