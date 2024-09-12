public struct ValidationResult: Sendable {
  public var valid: Bool
  public var location: ValidationLocation

  /// Required if valid == false
  public var errors: [ValidationResult]?
  public var annotations: [ValidationResult]?
}
