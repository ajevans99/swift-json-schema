public protocol ValidatableSchema {
  func validate(_ instance: JSONValue) -> ValidationResult
}
