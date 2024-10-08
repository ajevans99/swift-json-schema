/// A JSON property value component for use in ``JSONPropertyBuilder``.
///
/// This component is used to represent a key-value pair in a JSON object instance.
/// Not to be confused with ``JSONProperty`` which is used to represent a key-value pair in a JSON schema.
public struct JSONPropertyValue {
  let key: String
  let value: JSONValueRepresentable

  public init(key: String, @JSONValueBuilder builder: () -> JSONValueRepresentable) {
    self.key = key
    self.value = builder()
  }

  public init(key: String, value: JSONValueRepresentable) {
    self.key = key
    self.value = value
  }
}
