import JSONSchema

@attached(peer) public macro ArrayOptions(
  minContains: Int? = nil,
  maxContains: Int? = nil,
  minItems: Int? = nil,
  maxItems: Int? = nil,
  uniqueItems: Bool? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "ArrayOptionsMacro")
