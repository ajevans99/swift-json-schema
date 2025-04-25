import JSONSchema

@attached(peer)
public macro ObjectOptions(
  _ traits: ObjectTrait...
) = #externalMacro(module: "JSONSchemaMacro", type: "ObjectOptionsMacro")

public protocol ObjectTrait {}

public struct ObjectSchemaTrait: ObjectTrait {
  fileprivate init() {}

  fileprivate static let errorMessage =
    "This method should only be used within @ObjectOptions macro"
}

extension ObjectTrait where Self == ObjectSchemaTrait {
  public static func additionalProperties(
    @JSONSchemaBuilder _ content: @escaping () -> some JSONSchemaComponent
  ) -> ObjectSchemaTrait {
    fatalError(ObjectSchemaTrait.errorMessage)
  }

  public static func patternProperties(
    @JSONPropertySchemaBuilder _ patternProperties: @escaping () -> some PropertyCollection
  ) -> ObjectSchemaTrait {
    fatalError(ObjectSchemaTrait.errorMessage)
  }

  public static func unevaluatedProperties(
    @JSONSchemaBuilder _ content: @escaping () -> some JSONSchemaComponent
  ) -> ObjectSchemaTrait {
    fatalError(ObjectSchemaTrait.errorMessage)
  }

  public static func minProperties(_ value: Int) -> ObjectSchemaTrait {
    fatalError(ObjectSchemaTrait.errorMessage)
  }

  public static func maxProperties(_ value: Int) -> ObjectSchemaTrait {
    fatalError(ObjectSchemaTrait.errorMessage)
  }

  public static func propertyNames(
    @JSONSchemaBuilder _ content: @escaping () -> some JSONSchemaComponent
  ) -> ObjectSchemaTrait {
    fatalError(ObjectSchemaTrait.errorMessage)
  }
}
