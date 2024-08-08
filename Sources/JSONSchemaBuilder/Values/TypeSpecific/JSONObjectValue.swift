import JSONSchema

/// A JSON object value component for use in ``JSONValueBuilder``.
public struct JSONObjectValue: JSONValueRepresentable {
  public var value: JSONValue { .object(properties.mapValues(\.value)) }

  let properties: [String: JSONValueRepresentable]

  public init(properties: [String: JSONValueRepresentable] = [:]) { self.properties = properties }
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
