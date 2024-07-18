import JSONSchema

public enum JSONComposition {
  public struct AnyOf: JSONSchemaComponent {
    public var annotations: AnnotationOptions = .annotations()

    public var definition: Schema

    public init(@JSONSchemaBuilder _ builder: () -> [JSONSchemaComponent]) {
      definition = .noType(composition: .anyOf(builder().map(\.definition)))
    }
  }

  public struct AllOf: JSONSchemaComponent {
    public var annotations: AnnotationOptions = .annotations()

    public var definition: Schema

    public init(@JSONSchemaBuilder _ builder: () -> [JSONSchemaComponent]) {
      definition = .noType(composition: .allOf(builder().map(\.definition)))
    }
  }

  public struct OneOf: JSONSchemaComponent {
    public var annotations: AnnotationOptions = .annotations()

    public var definition: Schema

    public init(@JSONSchemaBuilder _ builder: () -> [JSONSchemaComponent]) {
      definition = .noType(composition: .oneOf(builder().map(\.definition)))
    }
  }

  public struct Not: JSONSchemaComponent {
    public var annotations: AnnotationOptions = .annotations()

    public var definition: Schema

    public init(@JSONSchemaBuilder _ builder: () -> JSONSchemaComponent) {
      definition = .noType(composition: .not(builder().definition))
    }
  }
}
