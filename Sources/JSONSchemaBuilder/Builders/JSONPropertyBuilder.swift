import JSONSchema

/// A result builder type that collects multiple ``JSONPropertyValue`` instances into a single array.
@resultBuilder public struct JSONPropertyBuilder {
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
