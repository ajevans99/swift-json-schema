@attached(extension, conformances: Schemable) @attached(member, names: named(schema))
public macro Schemable() =
  #externalMacro(module: "JSONSchemaMacro", type: "SchemableMacro")

public protocol Schemable { static var schema: JSONSchemaRepresentable { get } }
