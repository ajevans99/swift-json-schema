import JSONSchema

/// Captures property names encountered during validation.
public struct CapturedPropertyNames<Name: Hashable> {
  /// Property names that were validated successfully, in encounter order.
  public var seen: [Name]
  /// The original string keys from the instance.
  public var raw: [String]

  public init(seen: [Name] = [], raw: [String] = []) {
    self.seen = seen
    self.raw = raw
  }
}

extension JSONComponents {
  /// A JSON schema component that augments a base schema with `propertyNames` support
  /// and captures property names that successfully validate.
  public struct PropertyNames<
    Base: JSONSchemaComponent,
    Names: JSONSchemaComponent
  >: JSONSchemaComponent where Names.Output: Hashable {
    public var schemaValue: SchemaValue

    var base: Base
    let propertyNamesSchema: Names

    public init(base: Base, propertyNamesSchema: Names) {
      self.base = base
      self.propertyNamesSchema = propertyNamesSchema
      schemaValue = base.schemaValue
      schemaValue[Keywords.PropertyNames.name] = propertyNamesSchema.schemaValue.value
    }

    public func parse(
      _ input: JSONValue
    ) -> Parsed<(Base.Output, CapturedPropertyNames<Names.Output>), ParseIssue> {
      guard case .object(let dict) = input else {
        return .error(.typeMismatch(expected: .object, actual: input))
      }

      let baseResult = base.parse(input)

      var seen: [Names.Output] = []
      var raw: [String] = []
      for (key, _) in dict {
        switch propertyNamesSchema.parse(.string(key)) {
        case .valid(let name):
          seen.append(name)
          raw.append(key)
        case .invalid:
          continue
        }
      }

      let capture = CapturedPropertyNames(seen: seen, raw: raw)

      switch baseResult {
      case .valid(let baseOut):
        return .valid((baseOut, capture))
      case .invalid(let errs):
        return .invalid(errs)
      }
    }
  }
}

extension JSONSchemaComponent {
  /// Adds property name validation to the schema and captures any names that
  /// successfully validate.
  ///
  /// - Parameter content: A string schema component used to validate property names.
  /// - Returns: A new component that validates and captures property names.
  public func propertyNames<C: JSONSchemaComponent>(
    @JSONSchemaBuilder _ content: () -> C
  ) -> JSONComponents.PropertyNames<Self, C> where C.Output: Hashable {
    JSONComponents.PropertyNames(
      base: self,
      propertyNamesSchema: content()
    )
  }
}
