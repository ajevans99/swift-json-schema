import JSONSchema

public extension JSONSchemaRepresentable {
  func title(_ value: String) -> Self {
    var copy = self
    copy.annotations.title = value
    return copy
  }

  func description(_ value: String) -> Self {
    var copy = self
    copy.annotations.description = value
    return copy
  }

  func `default`(@JSONValueBuilder _ value: () -> JSONValueRepresentable) -> Self {
    var copy = self
    copy.annotations.default = value().value
    return copy
  }

  func examples(@JSONValueBuilder _ examples: () -> JSONValueRepresentable) -> Self {
    var copy = self
    copy.annotations.examples = examples().value
    return copy
  }
  
  func readOnly(_ value: Bool) -> Self {
    var copy = self
    copy.annotations.readOnly = value
    return copy
  }

  func writeOnly(_ value: Bool) -> Self {
    var copy = self
    copy.annotations.writeOnly = value
    return copy
  }

  func deprecated(_ value: Bool) -> Self {
    var copy = self
    copy.annotations.deprecated = value
    return copy
  }

  func comment(_ value: String) -> Self {
    var copy = self
    copy.annotations.comment = value
    return copy
  }
}
