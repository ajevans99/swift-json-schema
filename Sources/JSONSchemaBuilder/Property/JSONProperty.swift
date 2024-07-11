/// A JSON property component for use in ``JSONPropertySchemaBuilder``.
///
/// This component is used to represent a key-value pair in a JSON object.
/// The key is a `String` and the value is a ``JSONSchemaRepresentable``.
public struct JSONProperty {
  let key: String
  let value: JSONSchemaRepresentable

  public init(key: String, @JSONSchemaBuilder builder: () -> JSONSchemaRepresentable) {
    self.key = key
    self.value = builder()
  }

  public init(key: String, value: JSONSchemaRepresentable) {
    self.key = key
    self.value = value
  }
}
