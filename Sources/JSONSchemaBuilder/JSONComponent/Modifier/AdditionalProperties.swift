import JSONSchema

extension JSONComponents {
  public struct AdditionalProperties<Props: PropertyCollection, AdditionalProps: JSONSchemaComponent>: JSONSchemaComponent {
    public var annotations: AnnotationOptions {
      get { base.annotations }
      set { base.annotations = newValue }
    }

    public var definition: Schema {
      base.definition
    }

    var base: JSONObject<Props>
    let additionalPropertiesSchema: AdditionalProps

    public init(base: JSONObject<Props>, additionalProperties: AdditionalProps) {
      self.base = base
        .additionalProperties(.schema(additionalProperties.definition))
      self.additionalPropertiesSchema = additionalProperties
    }

    public func validate(_ input: JSONValue) -> Validated<(Props.Output, [String: AdditionalProps.Output]), String> {
      guard case let .object(dictionary) = input else {
        return .error("Not an object")
      }

      // Validate the base properties
      let baseValidation = base.validate(input)

      // Validate the additional properties
      var additionalProperties: [String: AdditionalProps.Output] = [:]
      for (key, value) in dictionary {
        if !base.properties.schema.keys.contains(key) {
          switch additionalPropertiesSchema.validate(value) {
          case .valid(let output):
            additionalProperties[key] = output
          case .invalid(let errors):
            return .invalid(errors)
          }
        }
      }

      // Combine the base properties and additional properties
      switch baseValidation {
      case .valid(let baseOutput):
        return .valid((baseOutput, additionalProperties))
      case .invalid(let errors):
        return .invalid(errors)
      }
    }
  }
}
