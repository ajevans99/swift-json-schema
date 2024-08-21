import JSONSchema

public protocol JSONComposableComponent: JSONSchemaComponent {
  var compositionOptions: CompositionOptions { get }
}

extension JSONComposableComponent {
  public var definition: Schema { .noType(annotations, composition: compositionOptions) }
}

public enum JSONComposition {
  /// A component that accepts any of the given schemas.
  public struct AnyOf<Components: JSONSchemaComponent, Output>: JSONComposableComponent
  where Components.Output == Output {
    public var annotations: AnnotationOptions = .annotations()

    let components: Components
    public let compositionOptions: CompositionOptions

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> Components
    ) {
      components = builder()
      compositionOptions = .anyOf([components.definition])
    }

    public func validate(_ value: JSONValue) -> Validated<Output, String> {
      components.validate(value)
//      fatalError()
//      components.validate(value)
//        .first { result in
//          switch result {
//          case .valid: return true
//          case .invalid: return false
//          }
//        } ?? .error("\(value) failed to match any of schemas")
    }
  }

  /// A component that requires all of the schemas to be valid.
//  public struct AllOf<Components: SchemaCollection, Output>: JSONComposableComponent
//  where Components.Output == Output {
//    public var annotations: AnnotationOptions = .annotations()
//
//    let components: Components
//    public let compositionOptions: CompositionOptions
//
//    public init(@JSONSchemaCollectionBuilder<Output> _ builder: () -> Components) {
//      components = builder()
//      compositionOptions = .allOf(components.definitions)
//    }
//
//    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
//      let results = components.validate(value)
//      for result in results {
//        if case .invalid(let error) = result { return .error("Failed allOf validation: \(error)") }
//      }
//      return .valid(value)
//    }
//  }

  /// A component that requires exactly one of the schemas to be valid.
//  public struct OneOf<Components: SchemaCollection, Output>: JSONComposableComponent
//  where Components.Output == Output {
//    public var annotations: AnnotationOptions = .annotations()
//
//    let components: Components
//    public let compositionOptions: CompositionOptions
//
//    public init(@JSONSchemaCollectionBuilder<Output> _ builder: () -> Components) {
//      components = builder()
//      compositionOptions = .oneOf(components.definitions)
//    }
//
//    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
//      let results = components.validate(value)
//      var validCount = 0
//      for result in results { if case .valid = result { validCount += 1 } }
//      guard validCount == 1 else { return .error("\(value) did not match exactly one schema") }
//      return .valid(value)
//    }
//  }

  /// A component that requires the value to not match the given schema.
  public struct Not<Component: JSONSchemaComponent, Output>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    let component: Component
    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> Component) {
      component = builder()
      compositionOptions = .not(component.definition)
    }

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      switch component.validate(value) {
      case .valid: return .error("\(value) is valid against the not schema.")
      case .invalid: return .valid(value)
      }
    }
  }
}
