import JSONSchema

extension JSONComponents {
  /// A component that validates property names against a schema and maps
  /// the resulting keys to strongly typed values.
  public struct PropertyNames<Base: JSONSchemaComponent, Names: JSONSchemaComponent, Value>: JSONSchemaComponent where Base.Output == [String: Value] {
    public var schemaValue: SchemaValue

    var base: Base
    let propertyNamesSchema: Names

    public init(base: Base, propertyNamesSchema: Names) {
      self.base = base
      self.propertyNamesSchema = propertyNamesSchema
      schemaValue = base.schemaValue
      schemaValue[Keywords.PropertyNames.name] = propertyNamesSchema.schemaValue.value
    }

    public func parse(_ input: JSONValue) -> Parsed<[Names.Output: Value], ParseIssue> {
      guard case .object = input else {
        return .error(.typeMismatch(expected: .object, actual: input))
      }

      switch base.parse(input) {
      case .valid(let dictionary):
        var typed: [Names.Output: Value] = [:]
        var errors: [ParseIssue] = []

        for (key, value) in dictionary {
          switch propertyNamesSchema.parse(.string(key)) {
          case .valid(let out):
            typed[out] = value
          case .invalid(let err):
            errors.append(contentsOf: err)
          }
        }

        if errors.isEmpty { return .valid(typed) }
        return .invalid(errors)

      case .invalid(let errs):
        return .invalid(errs)
      }
    }
  }
}
