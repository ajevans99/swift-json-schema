import JSONSchema

extension JSONComponents {
//  public struct Always<Output: Sendable>: JSONSchemaComponent {
//    public var definition: Schema { .noType() }
//
//    public var annotations: AnnotationOptions = .annotations()
//
//    let output: Output
//
//    public init(_ output: Output) {
//      self.output = output
//    }
//
//    public func validate(_ value: JSONValue) -> Validated<Output, String> {
//      return .valid(output)
//    }
//  }

  public struct Always: JSONSchemaComponent {
    public var definition: Schema { .noType() }

    public var annotations: AnnotationOptions = .annotations()

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      return .valid(value)
    }
  }
}
