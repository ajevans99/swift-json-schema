import JSONSchema
import OrderedCollections

/// A JSON object value component for use in ``JSONValueBuilder``.
public struct JSONObjectValue: JSONValueRepresentable {
  public var value: JSONValue {
    .object(properties.mapValues(\.value))
  }

  let properties: OrderedDictionary<String, JSONValueRepresentable>

  /// Constructs an empty object value.
  public init() {
    self.properties = [:]
  }

  /// Constructs an object value with declared key order preserved on emission.
  ///
  /// Pass a dictionary literal — `KeyValuePairs` retains declaration order
  /// from the literal, unlike Swift's `Dictionary`, whose iteration order is
  /// hash-seed-dependent.
  public init(properties: KeyValuePairs<String, JSONValueRepresentable>) {
    self.properties = OrderedDictionary(
      uniqueKeysWithValues: properties.map { ($0.key, $0.value) }
    )
  }

  /// Constructs an object value from an already-ordered map of properties.
  public init(properties: OrderedDictionary<String, JSONValueRepresentable>) {
    self.properties = properties
  }

  /// Constructs an object value from a Swift `Dictionary`.
  ///
  /// - Important: Swift `Dictionary` iteration order is hash-seed-dependent,
  ///   so the resulting JSON key order is **not** stable across processes.
  ///   Prefer the dictionary-literal initializer for reproducible output.
  public init(dictionary properties: [String: JSONValueRepresentable]) {
    self.properties = OrderedDictionary(
      uniqueKeysWithValues: properties.map { ($0.key, $0.value) }
    )
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
