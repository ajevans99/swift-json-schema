import JSONSchema

/// A JSON object value component for use in ``JSONValueBuilder``.
public struct JSONObjectValue: JSONValueRepresentable {
  public var value: JSONValue { .object(properties.mapValues(\.value)) }

  let properties: [String: JSONValueRepresentable]

  public init(properties: [String: JSONValueRepresentable] = [:]) { self.properties = properties }
}
