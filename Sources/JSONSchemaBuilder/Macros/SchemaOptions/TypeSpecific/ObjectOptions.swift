import JSONSchema

@attached(peer)
public macro ObjectOptions(
  _ traits: ObjectTrait...
) = #externalMacro(module: "JSONSchemaMacro", type: "ObjectOptionsMacro")

public protocol ObjectTrait {}

public struct MinProperties: ObjectTrait {
  let value: Int
}

public struct MaxProperties: ObjectTrait {
  let value: Int
}

public struct PropertyNames<C: JSONSchemaComponent>: ObjectTrait {
  @JSONSchemaBuilder let content: () -> C
}

public struct UnevaluatedProperties<C: JSONSchemaComponent>: ObjectTrait {
  @JSONSchemaBuilder let content: () -> C
}

public struct AdditionalProperties: ObjectTrait {
  @JSONSchemaBuilder let content: () -> any JSONSchemaComponent
}

public struct PatternProperties<P: PropertyCollection>: ObjectTrait {
  @JSONPropertySchemaBuilder let patternProperties: () -> P
}

public struct EmptyObjectTrait: ObjectTrait {}

extension ObjectTrait {
  public static func minProperties(_ value: Int) -> MinProperties {
    MinProperties(value: value)
  }
}

extension ObjectTrait where Self == EmptyObjectTrait {
  public static func additionalProperties(@JSONSchemaBuilder _ content: @escaping () -> some JSONSchemaComponent) -> EmptyObjectTrait {
    .init()
  }
}
