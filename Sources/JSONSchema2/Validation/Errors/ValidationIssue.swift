public enum ValidationIssue: Error {
  case typeMismatch
  case notMultipleOf

  // Number
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
}
