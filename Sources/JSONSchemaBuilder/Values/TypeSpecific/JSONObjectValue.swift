import JSONSchema
import OrderedCollections

/// A JSON object value component for use in ``JSONValueBuilder``.
public struct JSONObjectValue: JSONValueRepresentable {
  public var value: JSONValue {
    // `properties` is a Dictionary, whose iteration order is not stable
    // across processes. Sort keys before building the OrderedDictionary
    // so the emitted JSON is deterministic. Callers that need a specific
    // key order should use a builder that supplies an ordered source.
    .object(
      OrderedDictionary(
        uniqueKeysWithValues: properties.keys.sorted().map { ($0, properties[$0]!.value) }
      )
    )
  }

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
