public struct ValidationResult {
  var valid: Bool
  var location: ValidationLocation

  /// Required if valid == false
  var errors: [ValidationResult]?
  var annotations: [ValidationResult]?
}
