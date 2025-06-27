import JSONSchema

extension JSONSchemaComponent {
  public func constant(_ value: JSONValue) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Constant.name] = value
    return copy
  }
}
