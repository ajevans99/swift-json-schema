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
  public static func buildBlock<each Component: JSONSchemaComponent>(_ component: repeat each Component) -> SchemaTuple<repeat each Component> {
    .init(component: (repeat each component))
  }

  // MARK: Advanced builers

  public static func buildOptional<Component: JSONSchemaComponent>(_ component: Component?) -> JSONComponents.OptionalNoType<Component> {
    .init(wrapped: component)
  }

  public static func buildEither<TrueComponent, FalseComponent>(first component: TrueComponent) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .first(component) }

  public static func buildEither<TrueComponent, FalseComponent>(second component: FalseComponent) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .second(component) }
}

public struct SchemaTuple<each Component: JSONSchemaComponent>: JSONSchemaComponent {
  public var definition: Schema {
    // TODO: Multiple types should be supported here
    for component in repeat each component {
      return component.definition
    }
    return .noType()
  }

  public var annotations: AnnotationOptions {
    get {
      for component in repeat each component {
        return component.annotations
      }
      return .annotations()
    }
    set {
      fatalError()
    }
  }

  public var component: (repeat each Component)

  public func validate(_ input: JSONValue) -> Validated<(repeat (each Component).Output), String> {
    return zip(repeat (each component).validate(input))
  }
}
