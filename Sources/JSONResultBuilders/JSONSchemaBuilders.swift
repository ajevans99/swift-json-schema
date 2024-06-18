import JSONSchema

@resultBuilder
public struct JSONSchemaBuilder {
  public static func buildBlock(_ expression: JSONSchemaRepresentable) -> JSONSchemaRepresentable {
    expression
  }

  public static func buildBlock(_ components: JSONSchemaRepresentable...) -> [JSONSchemaRepresentable] {
    components
  }

  public static func buildBlock(_ components: [JSONSchemaRepresentable]) -> [JSONSchemaRepresentable] {
    components
  }

  // MARK: Advanced builers

  public static func buildOptional(_ component: JSONSchemaRepresentable?) -> JSONSchemaRepresentable {
    component ?? JSONNull()
  }

  public static func buildEither(first: JSONSchemaRepresentable) -> JSONSchemaRepresentable {
    first
  }

  public static func buildEither(second: JSONSchemaRepresentable) -> JSONSchemaRepresentable {
    second
  }

  public static func buildArray(_ components: [JSONSchemaRepresentable]) -> [JSONSchemaRepresentable] {
    components
  }
}
