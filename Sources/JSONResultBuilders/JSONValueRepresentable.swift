import JSONSchema

/// A component for use in ``JSONValueBuilder```.
public protocol JSONValueRepresentable {
  /// The value that this component represents.
  var value: JSONValue { get }
}
