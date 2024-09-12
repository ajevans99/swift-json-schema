public protocol ValidatableSchema: Equatable, Sendable {
  func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult
}

extension ValidatableSchema {
  public func validate(_ instance: JSONValue) -> ValidationResult {
    self.validate(instance, at: .init())
  }
}
