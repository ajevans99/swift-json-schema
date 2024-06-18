import JSONSchema

extension JSONSchemaRepresentable {
  public func title(_ value: String) -> Self {
    var copy = self
    copy.annotations.title = value
    return copy
  }

  public func description(_ value: String) -> Self {
    var copy = self
    copy.annotations.description = value
    return copy
  }

  public func `default`(@JSONValueBuilder _ value: () -> JSONValueRepresentable) -> Self {
    var copy = self
    copy.annotations.default = value().value
    return copy
  }

  public func examples(@JSONValueBuilder _ examples: () -> JSONValueRepresentable) -> Self {
    var copy = self
    copy.annotations.examples = examples().value
    return copy
  }

  public func readOnly(_ value: Bool) -> Self {
    var copy = self
    copy.annotations.readOnly = value
    return copy
  }

  public func writeOnly(_ value: Bool) -> Self {
    var copy = self
    copy.annotations.writeOnly = value
    return copy
  }

  public func deprecated(_ value: Bool) -> Self {
    var copy = self
    copy.annotations.deprecated = value
    return copy
  }

  public func comment(_ value: String) -> Self {
    var copy = self
    copy.annotations.comment = value
    return copy
  }
}
