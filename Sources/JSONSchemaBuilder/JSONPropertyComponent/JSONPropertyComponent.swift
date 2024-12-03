import JSONSchema

/// A component that represents a JSON property.
/// Used in the ``JSONObject/init(with:)`` initializer to define the properties of an object schema.
public protocol JSONPropertyComponent: Sendable {
  associatedtype Value: JSONSchemaComponent
  associatedtype Output

  var key: String { get }
  var isRequired: Bool { get }
  var value: Value { get }

  func parse(_ input: [String: JSONValue]) -> Parsed<Output, ParseIssue>
}
