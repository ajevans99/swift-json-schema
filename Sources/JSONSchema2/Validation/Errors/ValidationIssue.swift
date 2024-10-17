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
  case referenceValidationFailure(ref: String, errors: [ValidationError])

  case keywordFailure(keyword: KeywordIdentifier, errors: [ValidationError])
}

extension ValidationIssue {
  func makeValidationError(
    keyword: String,
    keywordLocation: JSONPointer,
    instanceLocation: JSONPointer
  ) -> ValidationError {
    switch self {
    case .keywordFailure(let keyword, let errors):
      .init(
        keyword: keyword,
        message: "Validation failed for keyword '\(keyword)'",
        keywordLocation: keywordLocation,
        instanceLocation: instanceLocation,
        errors: errors
      )
    case .referenceValidationFailure(let ref, let errors):
      .init(
        keyword: keyword,
        message: "Validation failed during reference validation '\(ref)'",
        keywordLocation: keywordLocation,
        instanceLocation: instanceLocation,
        errors: errors
      )
    default:
      .init(
        keyword: keyword,
        message: description,
        keywordLocation: keywordLocation,
        instanceLocation: instanceLocation
      )
    }
  }
}

extension ValidationIssue: CustomStringConvertible {
  public var description: String {
    switch self {
    // General
    case .typeMismatch:
      return "Type mismatch: the instance does not match the expected type."
    case .notEnumCase:
      return "The instance is not one of the allowed enum values."
    case .constantMismatch:
      return "The instance does not match the constant value specified in 'const'."

    // Number
    case .notMultipleOf:
      return "The number is not a multiple of the specified 'multipleOf' value."
    case .exceedsMaximum:
      return "The number exceeds the specified 'maximum' value."
    case .exceedsExclusiveMaximum:
      return "The number exceeds the specified 'exclusiveMaximum' value."
    case .belowMinimum:
      return "The number is below the specified 'minimum' value."
    case .belowExclusiveMinimum:
      return "The number is below the specified 'exclusiveMinimum' value."

    // String
    case .exceedsMaxLength:
      return "The string length exceeds the specified 'maxLength'."
    case .belowMinLength:
      return "The string length is less than the specified 'minLength'."
    case .patternMismatch:
      return "The string does not match the specified 'pattern'."

    // Arrays
    case .exceedsMaxItems:
      return "The array has more items than the specified 'maxItems'."
    case .belowMinItems:
      return "The array has fewer items than the specified 'minItems'."
    case .itemsNotUnique:
      return "The array items are not unique as required by 'uniqueItems'."
    case .containsInsufficientMatches:
      return "The array does not contain enough items matching the 'contains' schema."
    case .containsExcessiveMatches:
      return
        "The array contains more items matching the 'contains' schema than allowed by 'maxContains'."
    case .invalidItem:
      return "An item in the array failed to validate against the schema."

    // Objects
    case .exceedsMaxProperties:
      return "The object has more properties than the specified 'maxProperties'."
    case .belowMinProperties:
      return "The object has fewer properties than the specified 'minProperties'."
    case .missingRequiredProperty(let key):
      return "The required property '\(key)' is missing."
    case .missingDependentProperty(let key, let dependentOn):
      return "Property '\(key)' is missing, which is required when '\(dependentOn)' is present."
    case .invalidProperty:
      return "A property in the object failed to validate against the schema."
    case .invalidPatternProperty:
      return "A property name did not match any of the specified 'patternProperties' patterns."
    case .invalidAdditionalProperty:
      return "An additional property is not allowed by 'additionalProperties'."

    // Logical
    case .allOfFailed:
      return "The instance does not satisfy all of the schemas specified in 'allOf'."
    case .anyOfFailed:
      return "The instance does not satisfy any of the schemas specified in 'anyOf'."
    case .oneOfFailed:
      return "The instance does not satisfy exactly one schema specified in 'oneOf'."
    case .notFailed:
      return "The instance should not match the schema specified in 'not'."

    // Conditional
    case .conditionalFailed:
      return
        "The instance failed to validate against the 'if' condition and corresponding 'then' or 'else' schemas."
    case .invalidDependentSchema:
      return
        "The instance failed to validate against a dependent schema specified in 'dependentSchemas'."
    case .unevaluatedItemsFailed:
      return "The unevaluated items in the array do not match the 'unevaluatedItems' schema."
    case .unevaluatedPropertyFailed:
      return
        "The unevaluated properties in the object do not match the 'unevaluatedProperties' schema."

    // Reference
    case .invalidReference(let ref):
      return "Invalid reference: \(ref)"
    case .referenceValidationFailure(let ref, _):
      return "Validation failed for reference '\(ref)'."

    // General
    case .keywordFailure(let keyword, _):
      return "Validation failed for keyword '\(keyword)'."
    }
  }
}
