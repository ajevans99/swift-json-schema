import JSONSchema

public protocol JSONComposableComponent: JSONSchemaComponent {
  var compositionOptions: CompositionOptions { get }
}

extension JSONComposableComponent {
  public var definition: Schema { .noType(annotations, composition: compositionOptions) }
}

public enum JSONComposition {
  public struct AnyOf: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> [JSONSchemaComponent]) {
      compositionOptions = .anyOf(builder().map(\.definition))
    }
  }

  public struct AllOf: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> [JSONSchemaComponent]) {
      compositionOptions = .allOf(builder().map(\.definition))
    }
  }

  public struct OneOf: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> [JSONSchemaComponent]) {
      compositionOptions = .oneOf(builder().map(\.definition))
    }
  }

  public struct Not: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> JSONSchemaComponent) {
      compositionOptions = .not(builder().definition)
    }
  }
}
