@attached(extension, conformances: Schemable)
@attached(member, names: named(schema))
public macro Schemable() = #externalMacro(module: "JSONSchemaMacro", type: "SchemableMacro")

public protocol Schemable {
  associatedtype Schema: JSONSchemaComponent

  @JSONSchemaBuilder static var schema: Schema { get }
}
