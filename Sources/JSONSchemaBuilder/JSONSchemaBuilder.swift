import JSONSchema

/// A result builder type to build JSON schemas.
///
/// Here's an example of how you might use this builder to create a JSON schema for a product:
/// ```swift
/// JSONObject {
///   JSONProperty(key: "productId") {
///     JSONInteger().description("The unique identifier for a product")
///   }
///   JSONProperty(key: "productName")
///     JSONString().description("Name of the product")
///   }
/// }
/// .description("A product from Acme's catalog")
/// ```
@resultBuilder public struct JSONSchemaBuilder {
  public static func buildBlock(_ expression: JSONSchemaComponent) -> JSONSchemaComponent {
    expression
  }

  public static func buildBlock(_ components: JSONSchemaComponent...) -> [JSONSchemaComponent] {
    components
  }

  public static func buildBlock(_ components: [JSONSchemaComponent]) -> [JSONSchemaComponent] {
    components
  }

  // MARK: Advanced builers

  public static func buildOptional(_ component: JSONSchemaComponent?) -> JSONSchemaComponent {
    component ?? JSONNull()
  }

  public static func buildEither(first: JSONSchemaComponent) -> JSONSchemaComponent { first }

  public static func buildEither(second: JSONSchemaComponent) -> JSONSchemaComponent { second }

  public static func buildArray(_ components: [JSONSchemaComponent]) -> [JSONSchemaComponent] {
    components
  }
}
