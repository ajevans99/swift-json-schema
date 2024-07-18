/// A JSON property component for use in ``JSONPropertySchemaBuilder``.
///
/// This component is used to represent a key-value pair in a JSON object.
/// The key is a `String` and the value is a ``JSONSchemaComponent``.
public struct JSONProperty {
  let key: String
  let value: JSONSchemaComponent

  public init(key: String, @JSONSchemaBuilder builder: () -> JSONSchemaComponent) {
    self.key = key
    self.value = builder()
  }

  public init(key: String, value: JSONSchemaComponent) {
    self.key = key
    self.value = value
  }
}
