import JSONSchema

/// The result of validating `patternProperties` against an input object.
public struct PatternPropertiesParseResult<PatternOut> {
  public typealias MatchingKey = JSONKey

  public struct Match {
    /// The instance value for the match.
    public let value: PatternOut
    /// The regex that caused the match, from the schema.
    public let regex: String
  }

  /// The key is the instance string that matches the regex.
  public let matches: [MatchingKey: Match]
}

extension JSONComponents {
  /// A JSON schema component that augments a base schema with patternProperties support.
  /// Each key in the input object is tested against the provided regex patterns,
  /// and matched values are validated using the associated subschemas.
  public struct PatternProperties<
    Base: JSONSchemaComponent,
    PatternProps: PropertyCollection
  >: JSONSchemaComponent {
    public var schemaValue: SchemaValue

    var base: Base
    let patternPropertiesSchema: PatternProps

    public init(base: Base, patternPropertiesSchema: PatternProps) {
      self.base = base
      self.patternPropertiesSchema = patternPropertiesSchema
      schemaValue = base.schemaValue
      schemaValue[Keywords.PatternProperties.name] = patternPropertiesSchema.schemaValue.value
    }

    public func parse(
      _ input: JSONValue
    ) -> Parsed<(Base.Output, PatternPropertiesParseResult<PatternProps.Output>), ParseIssue> {
      ParsingScope.withRoot(self, value: input) { parseProperties(input) }
    }

    private func parseProperties(
      _ input: JSONValue
    ) -> Parsed<(Base.Output, PatternPropertiesParseResult<PatternProps.Output>), ParseIssue> {
      guard case .object(let dict) = input else {
        return .error(.typeMismatch(expected: .object, actual: input))
      }

      let baseResult = base.parse(input)

      var matches = [JSONKey: PatternPropertiesParseResult<PatternProps.Output>.Match]()
      for (patternString, _) in patternPropertiesSchema.schemaValue.object ?? [:] {
        let regex: Regex<AnyRegexOutput>
        do {
          regex = try compileSchemaRegex(patternString.rawValue)
        } catch {
          return .error(
            .invalidRegularExpression(
              pattern: patternString.rawValue,
              reason: String(describing: error)
            )
          )
        }
        for (key, value) in dict where key.rawValue.firstMatch(of: regex) != nil {
          let singleKeyDict = [patternString: value]
          let parsed = ParsingScope.$propertyLocation.withValue(
            .init(keyword: Keywords.PatternProperties.name, instanceKey: key.rawValue)
          ) {
            patternPropertiesSchema.validate(singleKeyDict)
          }
          switch parsed {
          case .valid(let out):
            matches[key] = .init(value: out, regex: patternString.rawValue)
          case .invalid:
            continue
          }
        }
      }

      switch baseResult {
      case .valid(let baseOut):
        return .valid((baseOut, .init(matches: matches)))
      case .invalid(let errs):
        return .invalid(errs)
      }
    }
  }
}
