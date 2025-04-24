import JSONSchema

/// The result of validating additionalProperties against an input object.
/// Stores all extra key-value pairs that were not handled by the base schema.
public struct AdditionalPropertiesParseResult<AdditionalOut> {
  public let matches: [String: AdditionalOut]
}

extension JSONComponents {
  /// A JSON schema component that augments a base schema with additionalProperties support.
  /// Any properties not consumed by the base schema are validated using a fallback subschema.
  public struct AdditionalProperties<
    Base: JSONSchemaComponent,
    AdditionalProps: JSONSchemaComponent
  >: JSONSchemaComponent {
    public var schemaValue: SchemaValue

    var base: Base
    let additionalPropertiesSchema: AdditionalProps

    public init(base: Base, additionalProperties: AdditionalProps) {
      self.base = base
      self.additionalPropertiesSchema = additionalProperties
      schemaValue = base.schemaValue
      schemaValue[Keywords.AdditionalProperties.name] = additionalProperties.schemaValue.value
    }

    public func parse(
      _ input: JSONValue
    ) -> Parsed<(Base.Output, AdditionalPropertiesParseResult<AdditionalProps.Output>), ParseIssue>
    {
      guard case .object(let dictionary) = input else {
        return .error(.typeMismatch(expected: .object, actual: input))
      }

      // Validate the base properties
      let baseValidation = base.parse(input)

      // Validate the additional properties
      var additionalProperties: [String: AdditionalProps.Output] = [:]
      for (key, value) in dictionary where base.schemaValue.object?.keys.contains(key) == false {
        switch additionalPropertiesSchema.parse(value) {
        case .valid(let output): additionalProperties[key] = output
        case .invalid(let errors): return .invalid(errors)
        }
      }

      // Combine the base properties and additional properties
      switch baseValidation {
      case .valid(let baseOutput): return .valid((baseOutput, .init(matches: additionalProperties)))
      case .invalid(let errors): return .invalid(errors)
      }
    }
  }
}
