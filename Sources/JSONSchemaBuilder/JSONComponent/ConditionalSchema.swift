import JSONSchema

// MARK: - Conditional schema component
public struct ConditionalSchema: JSONSchemaComponent {
  public var schemaValue: SchemaValue

  private let ifSchema: any JSONSchemaComponent
  private let thenSchema: any JSONSchemaComponent
  private let elseSchema: (any JSONSchemaComponent)?

  public init(
    if ifSchema: any JSONSchemaComponent,
    then thenSchema: any JSONSchemaComponent,
    else elseSchema: (any JSONSchemaComponent)? = nil
  ) {
    self.ifSchema = ifSchema
    self.thenSchema = thenSchema
    self.elseSchema = elseSchema

    var dict: [String: JSONValue] = [
      Keywords.If.name: ifSchema.schemaValue.value,
      Keywords.Then.name: thenSchema.schemaValue.value,
    ]
    if let e = elseSchema {
      dict[Keywords.Else.name] = e.schemaValue.value
    }
    self.schemaValue = .object(dict)
  }

  public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> {
    .valid(value)
  }
}

// MARK: - DSL helper
// swift-format-ignore: AlwaysUseLowerCamelCase
@inlinable
public func If(
  @JSONSchemaBuilder _ ifSchema: () -> some JSONSchemaComponent,
  then thenSchema: () -> some JSONSchemaComponent
) -> some JSONSchemaComponent<JSONValue> {
  ConditionalSchema(if: ifSchema(), then: thenSchema())
}

// swift-format-ignore: AlwaysUseLowerCamelCase
@inlinable
public func If(
  @JSONSchemaBuilder _ ifSchema: () -> some JSONSchemaComponent,
  then thenSchema: () -> some JSONSchemaComponent,
  else elseSchema: () -> some JSONSchemaComponent
) -> some JSONSchemaComponent<JSONValue> {
  ConditionalSchema(if: ifSchema(), then: thenSchema(), else: elseSchema())
}
