public struct Property {
  let key: String
  let value: JSONRepresentable

  public init(key: String, @JSONBuilder builder: () -> JSONRepresentable) {
    self.key = key
    self.value = builder()
  }

  public init(key: String, value: JSONRepresentable) {
    self.key = key
    self.value = value
  }
}
