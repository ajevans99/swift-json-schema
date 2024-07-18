import JSONSchema

@attached(peer) public macro NumberOptions(
  multipleOf: Double? = nil,
  minimum: Double? = nil,
  exclusiveMinimum: Bool? = nil,
  maximum: Double? = nil,
  exclusiveMaximum: Bool? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "NumberOptionsMacro")
