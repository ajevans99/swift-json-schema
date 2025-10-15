import JSONSchema

// MARK: - Conditional schema component
public struct ConditionalSchema<Output>: JSONSchemaComponent {
  public var schemaValue: SchemaValue

  private let matchesCondition: @Sendable (JSONValue) -> Bool
  private let whenConditionTrue: @Sendable (JSONValue) -> Parsed<Output, ParseIssue>
  private let whenConditionFalse: @Sendable (JSONValue) -> Parsed<Output, ParseIssue>

  public init(
    if ifSchema: any JSONSchemaComponent,
    then thenSchema: JSONComponents.AnySchemaComponent<Output>,
    else elseSchema: JSONComponents.AnySchemaComponent<Output>
  ) {
    self.matchesCondition = Self.makePredicate(from: ifSchema)
    self.whenConditionTrue = { value in thenSchema.parse(value) }
    self.whenConditionFalse = { value in elseSchema.parse(value) }

    self.schemaValue = Self.makeSchemaValue(
      ifValue: ifSchema.schemaValue.value,
      thenValue: thenSchema.schemaValue.value,
      elseValue: elseSchema.schemaValue.value
    )
  }

  public init(
    if ifSchema: any JSONSchemaComponent,
    then thenSchema: JSONComponents.AnySchemaComponent<Output>,
    fallback: @Sendable @escaping (JSONValue) -> Parsed<Output, ParseIssue>
  ) {
    self.matchesCondition = Self.makePredicate(from: ifSchema)
    self.whenConditionTrue = { value in thenSchema.parse(value) }
    self.whenConditionFalse = fallback

    self.schemaValue = Self.makeSchemaValue(
      ifValue: ifSchema.schemaValue.value,
      thenValue: thenSchema.schemaValue.value,
      elseValue: nil
    )
  }

  public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
    if matchesCondition(value) {
      return whenConditionTrue(value)
    } else {
      return whenConditionFalse(value)
    }
  }

  private static func makePredicate(
    from ifSchema: any JSONSchemaComponent
  ) -> @Sendable (JSONValue) -> Bool {
    let definition = ifSchema.definition()
    return { value in definition.validate(value).isValid }
  }

  private static func makeSchemaValue(
    ifValue: JSONValue,
    thenValue: JSONValue,
    elseValue: JSONValue?
  ) -> SchemaValue {
    var dict: [String: JSONValue] = [
      Keywords.If.name: ifValue,
      Keywords.Then.name: thenValue,
    ]
    if let elseValue {
      dict[Keywords.Else.name] = elseValue
    }
    return .object(dict)
  }
}

// MARK: - DSL helper
// swift-format-ignore: AlwaysUseLowerCamelCase
@inlinable
public func If(
  @JSONSchemaBuilder _ ifSchema: () -> some JSONSchemaComponent,
  then thenSchema: () -> some JSONSchemaComponent
) -> some JSONSchemaComponent<JSONValue> {
  let condition = ifSchema()
  let thenComponent = JSONComponents.PassthroughComponent(wrapped: thenSchema())
    .eraseToAnySchemaComponent()
  return ConditionalSchema(
    if: condition,
    then: thenComponent,
    fallback: { .valid($0) }
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
@inlinable
public func If<Then: JSONSchemaComponent, Else: JSONSchemaComponent>(
  @JSONSchemaBuilder _ ifSchema: () -> some JSONSchemaComponent,
  then thenSchema: () -> Then,
  else elseSchema: () -> Else
) -> some JSONSchemaComponent<Then.Output> where Then.Output == Else.Output {
  let condition = ifSchema()
  let thenComponent = thenSchema().eraseToAnySchemaComponent()
  let elseComponent = elseSchema().eraseToAnySchemaComponent()
  return ConditionalSchema(
    if: condition,
    then: thenComponent,
    else: elseComponent
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
@inlinable @_disfavoredOverload
public func If(
  @JSONSchemaBuilder _ ifSchema: () -> some JSONSchemaComponent,
  then thenSchema: () -> some JSONSchemaComponent,
  else elseSchema: () -> some JSONSchemaComponent
) -> some JSONSchemaComponent<JSONValue> {
  let condition = ifSchema()
  let thenComponent = JSONComponents.PassthroughComponent(wrapped: thenSchema())
    .eraseToAnySchemaComponent()
  let elseComponent = JSONComponents.PassthroughComponent(wrapped: elseSchema())
    .eraseToAnySchemaComponent()
  return ConditionalSchema(
    if: condition,
    then: thenComponent,
    else: elseComponent
  )
}
