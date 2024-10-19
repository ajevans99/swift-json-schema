import JSONSchema

@attached(peer) public macro ObjectOptions(
  minProperties: Int? = nil,
  maxProperties: Int? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "ObjectOptionsMacro")
