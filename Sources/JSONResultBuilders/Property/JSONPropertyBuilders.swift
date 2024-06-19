/// A result builder type that collects multiple ``JSONProperty`` instances into a single array.
@resultBuilder public struct JSONPropertySchemaBuilder {
  public static func buildBlock(_ components: [JSONProperty]...) -> [JSONProperty] {
    components.flatMap { $0 }
  }

  public static func buildBlock(_ components: JSONProperty...) -> [JSONProperty] { components }

  public static func buildEither(first component: [JSONProperty]) -> [JSONProperty] { component }

  public static func buildEither(second component: [JSONProperty]) -> [JSONProperty] { component }

  public static func buildOptional(_ component: [JSONProperty]?) -> [JSONProperty] {
    component ?? []
  }

  public static func buildArray(_ components: [[JSONProperty]]) -> [JSONProperty] {
    components.flatMap { $0 }
  }
}

extension JSONObject {
  /// Constructs a new `JSONObject` with the provided properties.
  ///
  /// Example:
  /// ```swift
  /// let schema = JSONObject {
  ///   JSONProperty(key: "name", value: JSONString())
  /// }
  /// ```
  /// which is equivalent to:
  /// ```swift
  /// let schema = JSONObject().properties {
  ///   JSONProperty(key: "name", value: JSONString())
  /// }
  /// ```
  /// - Parameter content: A closure that returns an array of `JSONProperty` instances.
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

extension JSONObjectValue {
  /// Constructs a new `JSONObjectValue` with the provided properties.
  ///
  /// Example:
  /// ```swift
  /// let value = JSONObjectValue {
  ///   JSONPropertyValue(key: "name", value: "value")
  /// }
  /// ```
  /// which is equivalent to:
  /// ```swift
  /// let value = JSONObjectValue(properties: [JSONPropertyValue(key: "name", value: "value")])
  /// ```
  public init(@JSONPropertyBuilder _ content: () -> [JSONPropertyValue]) {
    self.properties = content()
      .reduce(into: [:]) { partialResult, property in partialResult[property.key] = property.value }
  }
}
