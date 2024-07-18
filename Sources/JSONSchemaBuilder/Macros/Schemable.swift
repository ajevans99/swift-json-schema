@attached(extension, conformances: Schemable) @attached(member, names: named(schema))
public macro Schemable() = #externalMacro(module: "JSONSchemaMacro", type: "SchemableMacro")

public protocol Schemable { @JSONSchemaBuilder static var schema: JSONSchemaComponent { get } }
