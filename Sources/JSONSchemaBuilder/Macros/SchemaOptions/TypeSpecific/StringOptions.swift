import JSONSchema

@attached(peer) public macro StringOptions(
  minLength: Int? = nil,
  maxLength: Int? = nil,
  pattern: String? = nil,
  format: String? = nil
) = #externalMacro(module: "JSONSchemaMacro", type: "StringOptionsMacro")
