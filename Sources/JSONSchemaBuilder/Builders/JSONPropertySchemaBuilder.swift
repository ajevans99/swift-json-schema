import JSONSchema

@resultBuilder public struct JSONPropertySchemaBuilder {
  public static func buildBlock<Component: JSONPropertyComponent>(_ component: Component) -> Component {
    component
  }

  public static func buildBlock<each Component: JSONPropertyComponent>(_ component: repeat each Component) -> PropertyTuple<repeat each Component> {
    .init(property: (repeat each component))
  }

  public static func buildBlock<each Component: JSONPropertyComponent>(_ component: repeat each Component) -> [String: Schema] {
    self.buildBlock(repeat each component).schema
  }

  public static func buildOptional<Component: JSONPropertyComponent>(_ component: Component?) -> JSONPropertyComponents.OptionalNoType<Component> {
    .init(wrapped: component)
  }

  public static func buildEither<TrueComponent, FalseComponent>(first component: TrueComponent) -> JSONPropertyComponents.Conditional<TrueComponent, FalseComponent> { .first(component) }

  public static func buildEither<TrueComponent, FalseComponent>(second component: FalseComponent) -> JSONPropertyComponents.Conditional<TrueComponent, FalseComponent> { .second(component) }
}

public struct PropertyTuple<each Property: JSONPropertyComponent>: Sendable {
  let property: (repeat each Property)

  var schema: [String: Schema] {
    var output = [String: Schema]()
#if swift(>=6)
    for property in repeat each property {
      guard !property.key.isEmpty else { continue }

      output[property.key] = property.value.definition
    }
#else
    func schemaForProperty<Prop: JSONPropertyComponent>(_ property: Prop) {
      guard !property.key.isEmpty else { return }
      output[property.key] = property.value.definition
    }
    repeat schemaForProperty(each property)
#endif
    return output
  }

  var requiredKeys: [String] {
    var keys = [String]()
#if swift(>=6)
    for property in repeat each property {
      if property.isRequired {
        keys.append(property.key)
      }
    }
#else
    func addKeyIfRequired<Prop: JSONPropertyComponent>(_ property: Prop) {
      if property.isRequired {
        keys.append(property.key)
      }
    }
    repeat addKeyIfRequired(each property)
#endif
    return keys
  }

  func validate(dictionary: [String: JSONValue]) -> Validated<(repeat (each Property).Output), String> {
    zip(repeat (each property).validate(dictionary))
  }
}
