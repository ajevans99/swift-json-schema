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
@resultBuilder public enum JSONSchemaBuilder {
  public static func buildBlock<Component: JSONSchemaComponent>(_ component: Component) -> Component
  { component }

  public static func buildBlock(_ expression: Bool) -> JSONBooleanSchema {
    .init(value: expression)
  }

  // MARK: Advanced builers

  public static func buildOptional<Component: JSONSchemaComponent>(
    _ component: Component?
  ) -> JSONComponents.OptionalComponent<Component> { .init(wrapped: component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    first component: TrueComponent
  ) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .first(component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    second component: FalseComponent
  ) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .second(component) }
}

@resultBuilder public enum JSONSchemaCollectionBuilder<Output> {
  public static func buildPartialBlock<Component: JSONSchemaComponent>(
    first component: Component
  ) -> [JSONComponents.AnySchemaComponent<Output>] where Component.Output == Output {
    [component.eraseToAnySchemaComponent()]
  }

  public static func buildPartialBlock<Component: JSONSchemaComponent>(
    accumulated: [JSONComponents.AnySchemaComponent<Output>],
    next component: Component
  ) -> [JSONComponents.AnySchemaComponent<Output>] where Component.Output == Output {
    accumulated + [component.eraseToAnySchemaComponent()]
  }

  public static func buildPartialBlock(
    first components: [JSONComponents.AnySchemaComponent<Output>]
  ) -> [JSONComponents.AnySchemaComponent<Output>] { components }

  public static func buildPartialBlock(
    accumulated: [JSONComponents.AnySchemaComponent<Output>],
    next components: [JSONComponents.AnySchemaComponent<Output>]
  ) -> [JSONComponents.AnySchemaComponent<Output>] {
    accumulated + components
  }

  public static func buildOptional(
    _ component: [JSONComponents.AnySchemaComponent<Output>]?
  ) -> [JSONComponents.AnySchemaComponent<Output>] {
    component ?? []
  }

  public static func buildEither(
    first component: [JSONComponents.AnySchemaComponent<Output>]
  ) -> [JSONComponents.AnySchemaComponent<Output>] { component }

  public static func buildEither(
    second component: [JSONComponents.AnySchemaComponent<Output>]
  ) -> [JSONComponents.AnySchemaComponent<Output>] { component }

  public static func buildArray(
    _ components: [[JSONComponents.AnySchemaComponent<Output>]]
  ) -> [JSONComponents.AnySchemaComponent<Output>] {
    components.flatMap { $0 }
  }
}

extension JSONSchemaCollectionBuilder where Output == JSONValue {
  public static func buildPartialBlock<Component: JSONSchemaComponent>(
    first component: Component
  ) -> [JSONComponents.AnySchemaComponent<JSONValue>] {
    [JSONComponents.PassthroughComponent(wrapped: component).eraseToAnySchemaComponent()]
  }

  public static func buildPartialBlock<Component: JSONSchemaComponent>(
    accumulated: [JSONComponents.AnySchemaComponent<JSONValue>],
    next component: Component
  ) -> [JSONComponents.AnySchemaComponent<JSONValue>] {
    accumulated + [
      JSONComponents.PassthroughComponent(wrapped: component).eraseToAnySchemaComponent()
    ]
  }
}
