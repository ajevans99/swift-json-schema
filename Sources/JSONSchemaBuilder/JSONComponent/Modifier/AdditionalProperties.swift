import JSONSchema

/// The result of validating additionalProperties against an input object.
/// Stores all extra key-value pairs that were not handled by the base schema.
public struct AdditionalPropertiesParseResult<AdditionalOut> {
  public let matches: [String: AdditionalOut]
}

extension JSONComponents {
  /// A JSON schema component that augments a base schema with additionalProperties support.
  /// Properties not declared by `properties` or matched by `patternProperties` are parsed
  /// using the additional schema. Parsing failures are reported rather than dropping entries.
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
      ParsingScope.withRoot(self, value: input) { parseProperties(input) }
    }

    private func parseProperties(
      _ input: JSONValue
    ) -> Parsed<(Base.Output, AdditionalPropertiesParseResult<AdditionalProps.Output>), ParseIssue>
    {
      guard case .object(let dictionary) = input else {
        return .error(.typeMismatch(expected: .object, actual: input))
      }

      let baseValidation = base.parse(input)
      let enclosingSchema = ParsingScope.current?.evaluation?.schema.object
      let declaredProperties =
        enclosingSchema?[Keywords.Properties.name]?.object
        ?? schemaValue[Keywords.Properties.name]?.object ?? [:]
      let patternProperties =
        enclosingSchema?[Keywords.PatternProperties.name]?.object
        ?? schemaValue[Keywords.PatternProperties.name]?.object ?? [:]
      var patterns: [Regex<AnyRegexOutput>] = []
      for pattern in patternProperties.keys {
        do {
          patterns.append(try Regex(pattern))
        } catch {
          return .error(
            .invalidRegularExpression(pattern: pattern, reason: String(describing: error))
          )
        }
      }

      var additionalProperties: [String: AdditionalProps.Output] = [:]
      var additionalErrors: [ParseIssue] = []
      var hasAdditionalFailure = false
      for (key, value) in dictionary
      where declaredProperties[key] == nil
        && !patterns.contains(where: { key.firstMatch(of: $0) != nil })
      {
        switch ParsingScope.parse(
          additionalPropertiesSchema,
          value: value,
          schemaTokens: [Keywords.AdditionalProperties.name],
          instanceTokens: [key]
        ) {
        case .valid(let output): additionalProperties[key] = output
        case .invalid(let errors):
          hasAdditionalFailure = true
          additionalErrors.append(contentsOf: errors)
        }
      }

      switch baseValidation {
      case .valid(let baseOutput):
        if hasAdditionalFailure { return .invalid(additionalErrors) }
        return .valid((baseOutput, .init(matches: additionalProperties)))
      case .invalid(let errors): return .invalid(errors + additionalErrors)
      }
    }
  }
}
