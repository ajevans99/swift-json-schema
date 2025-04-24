import JSONSchema

@attached(peer)
public macro SchemaOptions(
  title: String? = nil,
  description: String? = nil,
  default: JSONValue? = nil,
  examples: JSONValue? = nil,
  readOnly: Bool? = nil,
  writeOnly: Bool? = nil,
  deprecated: Bool? = nil,
  comment: String? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "SchemaOptionsMacro")
