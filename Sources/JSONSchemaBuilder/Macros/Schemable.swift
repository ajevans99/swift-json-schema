import JSONSchema

@attached(extension, conformances: Schemable) @attached(member, names: named(schema))
public macro Schemable() = #externalMacro(module: "JSONSchemaMacro", type: "SchemableMacro")

public protocol Schemable {
  associatedtype Schema: JSONSchemaComponent

  @JSONSchemaBuilder static var schema: Schema { get }
}

extension Schemable {
  public static func validate(_ value: JSONValue, against validator: Validator = JSONValidator.default) -> Validation<Schema.Output> {
    schema.validate(value, against: validator)
  }
}
