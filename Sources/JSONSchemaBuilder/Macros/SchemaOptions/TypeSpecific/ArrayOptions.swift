import JSONSchema

@attached(peer)
public macro ArrayOptions(
  _ traits: ArrayTrait...
) = #externalMacro(module: "JSONSchemaMacro", type: "ArrayOptionsMacro")

public protocol ArrayTrait {}

public struct ArraySchemaTrait: ArrayTrait {
  fileprivate init() {}

  fileprivate static let errorMessage = "This method should only be used within @ArrayOptions macro"
}

extension ArrayTrait where Self == ArraySchemaTrait {
  public static func minContains(_ value: Int) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }

  public static func maxContains(_ value: Int) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }

  public static func minItems(_ value: Int) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }

  public static func maxItems(_ value: Int) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }

  public static func uniqueItems(_ value: Bool = true) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }

  public static func prefixItems(
    @JSONSchemaCollectionBuilder<JSONValue> _ prefixItems:
      @escaping () -> [JSONComponents
      .AnySchemaComponent<JSONValue>]
  ) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }

  public static func unevaluatedItems<Component: JSONSchemaComponent>(
    @JSONSchemaBuilder _ unevaluatedItems: @escaping () -> Component
  ) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }

  public static func contains(
    @JSONSchemaBuilder _ contains: @escaping () -> any JSONSchemaComponent
  ) -> ArraySchemaTrait {
    fatalError(ArraySchemaTrait.errorMessage)
  }
}
