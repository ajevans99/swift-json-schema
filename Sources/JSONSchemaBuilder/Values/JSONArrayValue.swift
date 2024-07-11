import JSONSchema

/// A JSON array value component for use in ``JSONValueBuilder``.
public struct JSONArrayValue: JSONValueRepresentable {
  public var value: JSONValue { .array(elements.map(\.value)) }

  let elements: [JSONValueRepresentable]

  public init(elements: [JSONValueRepresentable] = []) { self.elements = elements }
}
