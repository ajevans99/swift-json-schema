@resultBuilder
public struct JSONPropertySchemaBuilder {
  public static func buildBlock(_ components: [JSONProperty]...) -> [JSONProperty] {
    components.flatMap { $0 }
  }

  public static func buildBlock(_ components: JSONProperty...) -> [JSONProperty] {
    components
  }

  public static func buildEither(first component: [JSONProperty]) -> [JSONProperty] {
    component
  }

  public static func buildEither(second component: [JSONProperty]) -> [JSONProperty] {
    component
  }

  public static func buildOptional(_ component: [JSONProperty]?) -> [JSONProperty] {
    component ?? []
  }

  public static func buildArray(_ components: [[JSONProperty]]) -> [JSONProperty] {
    components.flatMap { $0 }
  }
}

extension JSONObject {
  public init(@JSONPropertySchemaBuilder _ content: () -> [JSONProperty]) {
    annotations = .annotations()
    options = .options(
      properties: content()
        .reduce(into: [:]) { partialResult, property in
          partialResult[property.key] = property.value.schema
        }
    )
  }
}

@resultBuilder
public struct JSONPropertyBuilder {
  public static func buildBlock(_ components: [JSONPropertyValue]...) -> [JSONPropertyValue] {
    components.flatMap { $0 }
  }

  public static func buildBlock(_ components: JSONPropertyValue...) -> [JSONPropertyValue] {
    components
  }

  public static func buildEither(first component: [JSONPropertyValue]) -> [JSONPropertyValue] {
    component
  }

  public static func buildEither(second component: [JSONPropertyValue]) -> [JSONPropertyValue] {
    component
  }

  public static func buildOptional(_ component: [JSONPropertyValue]?) -> [JSONPropertyValue] {
    component ?? []
  }

  public static func buildArray(_ components: [[JSONPropertyValue]]) -> [JSONPropertyValue] {
    components.flatMap { $0 }
  }
}

extension JSONObjectValue {
  public init(@JSONPropertyBuilder _ content: () -> [JSONPropertyValue]) {
    self.properties = content()
      .reduce(into: [:]) { partialResult, property in
        partialResult[property.key] = property.value
      }
  }
}
