@attached(extension, conformances: Schemable)
@attached(member, names: named(schema))
public macro Schemable() =
  #externalMacro(module: "JSONSchemaMacros", type: "SchemableMacro")

public protocol Schemable {
  static var schema: JSONSchemaRepresentable { get }
}
