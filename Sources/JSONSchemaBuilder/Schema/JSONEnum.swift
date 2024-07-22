import JSONSchema

public struct JSONEnum: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .noType(annotations, enumValues: values) }

  let values: [JSONValue]

  public init(@JSONValueBuilder _ builder: () -> JSONValueRepresentable) {
    values = Array(builder().value)
  }

  public init(values: [JSONValue]) { self.values = values }
}
