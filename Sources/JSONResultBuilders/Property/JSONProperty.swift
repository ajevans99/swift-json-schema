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
