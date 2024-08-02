import JSONSchema

public protocol JSONPropertyComponent: Sendable {
  associatedtype Value: JSONSchemaComponent
  associatedtype Output

  var key: String { get }
  var isRequired: Bool { get }
  var value: Value { get }

  func validate(_ input: [String: JSONValue]) -> Validated<Output, String>
}
