import JSONSchema

/// The result of validating patternProperties against an input object.
/// Stores all matches as a mapping from the pattern string to an array of outputs,
/// since multiple patterns may match the same key.
public struct PatternPropertiesParseResult<PatternOut> {
  public let matches: [String: [PatternOut]]
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
      guard case .object(let dict) = input else {
        return .error(.typeMismatch(expected: .object, actual: input))
      }

      let baseResult = base.parse(input)

      var matches = [String: [PatternProps.Output]]()
      for (patternString, _) in patternPropertiesSchema.schemaValue.object ?? [:] {
        let regex: Regex<AnyRegexOutput>
        do {
          regex = try Regex<AnyRegexOutput>(patternString)
        } catch {
          // Skip invalid regex patterns
          continue
        }
        for (key, value) in dict where key.firstMatch(of: regex) != nil {
          let singleKeyDict = [patternString: value]
          switch patternPropertiesSchema.validate(singleKeyDict) {
          case .valid(let out):
            matches[patternString, default: []].append(out)
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
