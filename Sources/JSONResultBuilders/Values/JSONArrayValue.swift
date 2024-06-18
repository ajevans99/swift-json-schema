import JSONSchema

public struct JSONArrayValue: JSONValueRepresentable {
  public var value: JSONValue { .array(elements.map(\.value)) }

  let elements: [JSONValueRepresentable]

  public init(elements: [JSONValueRepresentable] = []) { self.elements = elements }
}
