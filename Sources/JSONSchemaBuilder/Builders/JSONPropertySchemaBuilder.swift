import JSONSchema

@resultBuilder public struct JSONPropertySchemaBuilder {
  public static func buildBlock() -> PropertyTuple<JSONPropertyComponents.EmptyProperty> {
    .init(property: .init())
  }

  public static func buildBlock<each Component: JSONPropertyComponent>(_ component: repeat each Component) -> PropertyTuple<repeat each Component> {
    .init(property: (repeat each component))
  }

  public static func buildBlock() -> [String: Schema] {
    [:]
  }

  public static func buildBlock<each Component: JSONPropertyComponent>(_ component: repeat each Component) -> [String: Schema] {
    self.buildBlock(repeat each component).schema
  }

  //  public static func buildBlock(_ components: [JSONProperty]...) -> [JSONProperty] {
  //    components.flatMap { $0 }
  //  }
  //
  //  public static func buildBlock(_ components: JSONProperty...) -> [JSONProperty] { components }
  //
  //  public static func buildEither(first component: [JSONProperty]) -> [JSONProperty] { component }
  //
  //  public static func buildEither(second component: [JSONProperty]) -> [JSONProperty] { component }
  //
  //  public static func buildOptional(_ component: [JSONProperty]?) -> [JSONProperty] {
  //    component ?? []
  //  }
  //
  //  public static func buildArray(_ components: [[JSONProperty]]) -> [JSONProperty] {
  //    components.flatMap { $0 }
  //  }
}

public struct PropertyTuple<each Property: JSONPropertyComponent>: Sendable {
  let property: (repeat each Property)

  var schema: [String: Schema] {
    var output = [String: Schema]()
    for property in repeat each property {
      output[property.key] = property.value.definition
    }
    return output
  }

  var requiredKeys: [String] {
    var keys = [String]()
    for property in repeat each property {
      if property.isRequired {
        keys.append(property.key)
      }
    }
    return keys
  }

  func validate(dictionary: [String: JSONValue]) -> Validated<(repeat (each Property).Output), String> {
    zip(repeat (each property).validate(dictionary))
  }
}
