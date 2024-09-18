public enum ValidationIssue: Error, Codable, Equatable {
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
  case invalidItem

  // Objects
  case exceedsMaxProperties
  case belowMinProperties
  case missingRequiredProperty(key: String)
  case missingDependentProperty(key: String, dependentOn: String)
  case invalidProperty
  case invalidPatternProperty
  case invalidAdditionalProperty

  case allOfFailed
  case anyOfFailed
  case oneOfFailed
  case notFailed

  case conditionalFailed
  case invalidDependentSchema
  case unevaluatedItemsFailed
  case unevaluatedPropertyFailed

  case invalidReference(String)
  case referenceValidationFailed
}
