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

  // MARK: Advanced builers

  public static func buildOptional<Component: JSONSchemaComponent>(
    _ component: Component?
  ) -> JSONComponents.OptionalNoType<Component> { .init(wrapped: component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    first component: TrueComponent
  ) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .first(component) }

  public static func buildEither<TrueComponent, FalseComponent>(
    second component: FalseComponent
  ) -> JSONComponents.Conditional<TrueComponent, FalseComponent> { .second(component) }
}

@resultBuilder public enum JSONSchemaCollectionBuilder<Output> {
//  public static func buildBlock<Component: JSONSchemaComponent>(
//    _ component: Component
//  ) -> SchemaTuple<Component, Output> { .init(components: [component]) }
//
//  public static func buildBlock<Component: JSONSchemaComponent>(
//    _ components: Component...
//  ) -> SchemaTuple<Component, Output> { .init(components: components) }

  public static func buildPartialBlock<C: JSONSchemaComponent>(first: C) -> C {
    first
  }

  // TRY: accumunlated should be schemacollection, next is schema component
  // Need array for composition no matter what. I don't think zipping is the right choice here
  // Output is the right track, schema's need to match output type across composition
  public static func buildPartialBlock<C0, C1>(accumulated: C0, next: C1) -> SchemaPair<C0, C1>
  where C0.Output == C1.Output {
    .init(c0: accumulated, c1: next)
  }
}

//public struct SchemaSingle<Component: JSONSchemaComponent>: SchemaCollection
//where Component.Output == Component.Output {
//  public let component: Component
//
//  public var definitions: [Schema] { [component.definition] }
//
//  public func validate(_ input: JSONValue) -> [Validated<Component.Output, String>] {
//    [component.validate(input)]
//  }
//}

public struct SchemaPair<C0: JSONSchemaComponent, C1: JSONSchemaComponent>: JSONSchemaComponent
where C0.Output == C1.Output {
  public let c0: C0, c1: C1

  public var definition: Schema { .array() }

  public var annotations: AnnotationOptions { get { .annotations() } set {} }

  public func validate(_ value: JSONValue) -> Validated<[C0.Output], String> {
    zip(c0.validate(value), c1.validate(value))
  }
}

//public protocol SchemaCollection: Sendable {
//  associatedtype Output
//  var definitions: [Schema] { get }
//  func validate(_ input: JSONValue) -> [Validated<Output, String>]
//}

//public struct SchemaTuple<Component: JSONSchemaComponent, Output>: SchemaCollection
//where Component.Output == Output {
//  public var definitions: [Schema] {
//    var definitions = [Schema]()
//    #if swift(>=6)
//      for component in repeat each component { definitions.append(component.definition) }
//
//    #else
//      func getDefinition<Comp: JSONSchemaComponent>(_ component: Comp) {
//        definitions.append(component.definition)
//      }
//      repeat getDefinition(each component)
//    #endif
//    return definitions
//    return components.map(\.definition)
//  }
//
//  public var components: [Component]
//
//  public func validate(_ input: JSONValue) -> [Validated<Output, String>] {
//    var results = [Validated<Output, String>]()
//    #if swift(>=6)
//      for component in repeat each component {
//        switch component.validate(input) {
//        case .valid: results.append(.valid(input))
//        case .invalid(let errors): results.append(.invalid(errors))
//        }
//      }
//    #else
//      func validateComponent<Comp: JSONSchemaComponent>(_ component: Comp) {
//        switch component.validate(input) {
//        case .valid: results.append(.valid(input))
//        case .invalid(let errors): results.append(.invalid(errors))
//        }
//      }
//      repeat validateComponent(each component)
//    #endif
//    return results
//    return components.map { $0.validate(input) }
//  }
//}
