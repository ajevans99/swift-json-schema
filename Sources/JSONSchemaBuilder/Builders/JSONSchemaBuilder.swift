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
  public static func buildBlock<Component: JSONSchemaComponent>(_ component: Component) -> Component {
    component
  }

  // MARK: Advanced builers

  public static func buildOptional<Component: JSONSchemaComponent>(_ component: Component?) -> JSONComponents.OptionalNoType<Component> {
    .init(wrapped: component)
  }

  public static func buildEither<TrueComponent, FalseComponent>(first component: TrueComponent) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .first(component) }

  public static func buildEither<TrueComponent, FalseComponent>(second component: FalseComponent) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .second(component) }
}

@resultBuilder public struct JSONSchemaCollectionBuilder {
  public static func buildBlock<Component: JSONSchemaComponent>(_ component: Component) -> SchemaTuple<Component> {
    .init(component: component)
  }

  public static func buildBlock<each Component: JSONSchemaComponent>(_ component: repeat each Component) -> SchemaTuple<repeat each Component> {
    .init(component: (repeat each component))
  }
}

public protocol SchemaCollection: Sendable {
//  associatedtype Output

  var definitions: [Schema] { get }
  func validate(_ input: JSONValue) -> [Validated<JSONValue, String>]
}

public struct SchemaTuple<each Component: JSONSchemaComponent>: SchemaCollection {
  public var definitions: [Schema] {
    var definitions = [Schema]()
#if swift(>=6)
    for component in repeat each component {
      definitions.append(component.definition)
    }

#else
    func getDefinition<Comp: JSONSchemaComponent>(_ component: Comp) {
      definitions.append(component.definition)
    }
    repeat getDefinition(each component)
#endif
    return definitions
  }

  public var component: (repeat each Component)

  public func validate(_ input: JSONValue) -> [Validated<JSONValue, String>] {
    var results = [Validated<JSONValue, String>]()
    for component in repeat each component {
      switch component.validate(input) {
      case .valid:
        results.append(.valid(input))
      case .invalid(let errors):
        results.append(.invalid(errors))
      }
    }
    return results
  }
}
