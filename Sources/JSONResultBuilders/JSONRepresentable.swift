import JSONSchema

public protocol JSONRepresentable {
  var value: JSONValue { get }
}
