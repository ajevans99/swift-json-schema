public indirect enum ValidationIssue: Error, Codable {
  case typeMismatch
  case notEnumCase
  case constantMismatch

  // Number
  case notMultipleOf
  case exceedsMaximum
  case exceedsExclusiveMaximum
  case belowMinimum
  case belowExclusiveMinimum

  // String
  case exceedsMaxLength
  case belowMinLength
  case patternMismatch

  // Arrays
  case exceedsMaxItems
  case belowMinItems
  case itemsNotUnique
  case containsInsufficientMatches
  case containsExcessiveMatches
  case invalidItem(ValidationResult)

  // Objects
  case exceedsMaxProperties
  case belowMinProperties
  case missingRequiredProperty(key: String)
  case missingDependentProperty(key: String, dependentOn: String)
  case invalidProperty(ValidationResult)
  case invalidPatternProperty(ValidationResult)
  case invalidAdditionalProperty(ValidationResult)
}
