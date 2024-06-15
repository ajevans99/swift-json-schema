@resultBuilder
public struct PropertyBuilder {
  public static func buildBlock(_ components: Property...) -> [Property] {
    components
  }
}

extension JSONObjectElement {
  public init(@PropertyBuilder _ content: () -> [Property]) {
    self.properties = content()
      .reduce(into: [:]) { partialResult, property in
        partialResult[property.key] = property.value
      }
  }
}
