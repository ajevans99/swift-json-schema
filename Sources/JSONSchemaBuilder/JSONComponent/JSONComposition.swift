import JSONSchema

public protocol JSONComposableComponent: JSONSchemaComponent {
  var compositionOptions: CompositionOptions { get }
}

extension JSONComposableComponent {
  public var definition: Schema { .noType(annotations, composition: compositionOptions) }

  public func validate(_ value: JSONValue) -> Validated<Void, String> {
    .error("Validation on composable components is not yet supported")
  }
}

public enum JSONComposition {
  public struct AnyOf<Component: JSONSchemaComponent>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> [Component]) {
      compositionOptions = .anyOf(builder().map(\.definition))
    }
  }

  public struct AllOf<Component: JSONSchemaComponent>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> [Component]) {
      compositionOptions = .allOf(builder().map(\.definition))
    }
  }

  public struct OneOf<Component: JSONSchemaComponent>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> [Component]) {
      compositionOptions = .oneOf(builder().map(\.definition))
    }
  }

  public struct Not<Component: JSONSchemaComponent>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> Component) {
      compositionOptions = .not(builder().definition)
    }
  }
}
