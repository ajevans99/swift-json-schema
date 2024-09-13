public struct ValidationResult: Sendable, Codable, Equatable {
  public let valid: Bool
  public let location: ValidationLocation

  /// Required if valid == false
  public let errors: [ValidationResult]?
  public let error: ValidationIssue?
  public let annotations: [ValidationResult]?

  init(
    valid: Bool,
    location: ValidationLocation,
    errors: [ValidationResult]? = nil,
    error: ValidationIssue? = nil,
    annotations: [ValidationResult]? = nil
  ) {
    self.valid = valid
    self.location = location
    self.errors = errors
    self.error = error
    self.annotations = annotations
  }
}
