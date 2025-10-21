@attached(extension, conformances: Schemable)
@attached(member, names: named(schema), named(keyEncodingStrategy), named(encode(_:)), named(toJSONValue()))
public macro Schemable(
  keyStrategy: KeyEncodingStrategies? = nil,
  generateEncoding: Bool = false
) = #externalMacro(module: "JSONSchemaMacro", type: "SchemableMacro")

public protocol Schemable {
  associatedtype Schema: JSONSchemaComponent

  @JSONSchemaBuilder static var schema: Schema { get }
  static var keyEncodingStrategy: KeyEncodingStrategies { get }
}

extension Schemable {
  public static var keyEncodingStrategy: KeyEncodingStrategies { .identity }
}
