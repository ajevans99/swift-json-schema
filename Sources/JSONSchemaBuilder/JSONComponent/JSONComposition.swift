import JSONSchema

public protocol JSONComposableComponent: JSONSchemaComponent {
  var compositionOptions: CompositionOptions { get }
}

extension JSONComposableComponent {
  public var definition: Schema { .noType(annotations, composition: compositionOptions) }
}

public enum JSONComposition {
  public struct AnyOf<Components: SchemaCollection>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    let components: Components
    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaCollectionBuilder _ builder: () -> Components) {
      components = builder()
      compositionOptions = .anyOf(components.definitions)
    }

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      components.validate(value)
        .first { result in
          switch result {
          case .valid:
            return true
          case .invalid:
            return false
          }
        } ?? .error("\(value) failed to many any of schemas")
    }
  }

  public struct AllOf<Components: SchemaCollection>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    let components: Components
    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaCollectionBuilder _ builder: () -> Components) {
      components = builder()
      compositionOptions = .allOf(components.definitions)
    }

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      let results = components.validate(value)
      for result in results {
        if case .invalid(let error) = result {
          return .error("Failed allOf validation: \(error)")
        }
      }
      return .valid(value)
    }
  }

  public struct OneOf<Components: SchemaCollection>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    let components: Components
    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaCollectionBuilder _ builder: () -> Components) {
      components = builder()
      compositionOptions = .oneOf(components.definitions)
    }

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      let results = components.validate(value)
      var validCount = 0
      for result in results {
        if case .valid = result {
          validCount += 1
        }
      }
      if validCount == 1 {
        return .valid(value)
      } else {
        return .error("\(value) did not match exactly one schema")
      }
    }
  }

  public struct Not<Component: JSONSchemaComponent>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    let component: Component
    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> Component) {
      component = builder()
      compositionOptions = .not(component.definition)
    }

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      switch component.validate(value) {
      case .valid:
        return .error("\(value) is valid against the not schema.")
      case .invalid:
        return .valid(value)
      }
    }
  }
}
