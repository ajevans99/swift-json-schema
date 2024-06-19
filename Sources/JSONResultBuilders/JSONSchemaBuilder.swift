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
  public static func buildBlock(_ expression: JSONSchemaRepresentable) -> JSONSchemaRepresentable {
    expression
  }

  public static func buildBlock(
    _ components: JSONSchemaRepresentable...
  ) -> [JSONSchemaRepresentable] { components }

  public static func buildBlock(
    _ components: [JSONSchemaRepresentable]
  ) -> [JSONSchemaRepresentable] { components }

  // MARK: Advanced builers

  public static func buildOptional(_ component: JSONSchemaRepresentable?) -> JSONSchemaRepresentable
  { component ?? JSONNull() }

  public static func buildEither(first: JSONSchemaRepresentable) -> JSONSchemaRepresentable {
    first
  }

  public static func buildEither(second: JSONSchemaRepresentable) -> JSONSchemaRepresentable {
    second
  }

  public static func buildArray(
    _ components: [JSONSchemaRepresentable]
  ) -> [JSONSchemaRepresentable] { components }
}
