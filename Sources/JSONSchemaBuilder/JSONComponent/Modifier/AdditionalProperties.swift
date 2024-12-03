import JSONSchema

extension JSONComponents {
  public struct AdditionalProperties<
    Props: PropertyCollection,
    AdditionalProps: JSONSchemaComponent
  >: JSONSchemaComponent {
    public var schemaValue: [KeywordIdentifier: JSONValue]

    var base: JSONObject<Props>
    let additionalPropertiesSchema: AdditionalProps

    public init(base: JSONObject<Props>, additionalProperties: AdditionalProps) {
      self.base = base
      self.additionalPropertiesSchema = additionalProperties
      schemaValue = base.schemaValue
      schemaValue[Keywords.AdditionalProperties.name] = .object(additionalProperties.schemaValue)
    }

    public func parse(
      _ input: JSONValue
    ) -> Parsed<(Props.Output, [String: AdditionalProps.Output]), ParseIssue> {
      guard case .object(let dictionary) = input else { return .error(.typeMismatch(expected: .object, actual: input)) }

      // Validate the base properties
      let baseValidation = base.parse(input)

      // Validate the additional properties
      var additionalProperties: [String: AdditionalProps.Output] = [:]
      for (key, value) in dictionary where !base.schemaValue.keys.contains(key) {
        switch additionalPropertiesSchema.parse(value) {
        case .valid(let output): additionalProperties[key] = output
        case .invalid(let errors): return .invalid(errors)
        }
      }

      // Combine the base properties and additional properties
      switch baseValidation {
      case .valid(let baseOutput): return .valid((baseOutput, additionalProperties))
      case .invalid(let errors): return .invalid(errors)
      }
    }
  }
}
