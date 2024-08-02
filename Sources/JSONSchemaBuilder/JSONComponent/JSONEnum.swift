import JSONSchema

public struct JSONEnum: JSONSchemaComponent {
  public var annotations: AnnotationOptions = .annotations()

  public var definition: Schema { .noType(annotations, enumValues: cases) }

  let cases: [JSONValue]

  public init(@JSONValueBuilder _ builder: () -> JSONValueRepresentable) {
    cases = Array(builder().value)
  }

  public init(cases: [JSONValue]) { self.cases = cases }

  public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
    for `case` in cases {
      if `case` == value {
        return .valid(`case`)
      }
    }
    return .error("Did not match \(value) with enum case \(cases)")
  }
}
