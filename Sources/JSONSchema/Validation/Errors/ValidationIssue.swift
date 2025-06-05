public enum ValidationIssue: Error, Codable, Equatable {
  case typeMismatch(expected: [JSONType], actual: JSONType)
  case notEnumCase(value: JSONValue, allowedValues: [JSONValue])
  case constantMismatch(expected: JSONValue, actual: JSONValue)

  // Number
  case notMultipleOf(number: Double, multiple: Double)
  case exceedsMaximum(number: Double, maximum: Double)
  case exceedsExclusiveMaximum(number: Double, maximum: Double)
  case belowMinimum(number: Double, minimum: Double)
  case belowExclusiveMinimum(number: Double, minimum: Double)

  // String
  case exceedsMaxLength(string: String, maxLength: Int)
  case belowMinLength(string: String, minLength: Int)
  case patternMismatch(string: String, pattern: String)
  case invalidFormat(name: String, value: String)

  // Arrays
  case exceedsMaxItems(count: Int, maxItems: Int)
  case belowMinItems(count: Int, minItems: Int)
  case itemsNotUnique
  case containsInsufficientMatches(count: Int, required: Int)
  case containsExcessiveMatches(count: Int, maxAllowed: Int)
  case invalidItem(index: Int, error: ValidationError)

  // Objects
  case exceedsMaxProperties(count: Int, maxProperties: Int)
  case belowMinProperties(count: Int, minProperties: Int)
  case missingRequiredProperty(key: String)
  case missingDependentProperty(key: String, dependentOn: String)
  case invalidProperty(key: String, error: ValidationError)
  case invalidPatternProperty(key: String, pattern: String)
  case invalidAdditionalProperty(key: String)

  // Logical
  case allOfFailed(errors: [ValidationError])
  case anyOfFailed(errors: [ValidationError])
  case oneOfFailed(errors: [ValidationError])
  case notFailed

  // Conditional
  case conditionalFailed(condition: String, errors: [ValidationError])
  case invalidDependentSchema(key: String, errors: [ValidationError])
  case unevaluatedItemsFailed(errors: [ValidationError])
  case unevaluatedPropertyFailed(errors: [ValidationError])

  // Reference
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
    case .typeMismatch(let expected, let actual):
      return "Expected type '\(expected)' but found '\(actual)'"
    case .notEnumCase(let value, let allowedValues):
      return
        "'\(value)' is not one of the allowed values: \(allowedValues.map(\.description).joined(separator: ", "))"
    case .constantMismatch(let expected, let actual):
      return "Expected constant value '\(expected)' but found '\(actual)'"

    // Number
    case .notMultipleOf(let number, let multiple):
      return "\(number) is not a multiple of \(multiple)"
    case .exceedsMaximum(let number, let maximum):
      return "\(number) exceeds maximum value of \(maximum)"
    case .exceedsExclusiveMaximum(let number, let maximum):
      return "\(number) exceeds exclusive maximum value of \(maximum)"
    case .belowMinimum(let number, let minimum):
      return "\(number) is below minimum value of \(minimum)"
    case .belowExclusiveMinimum(let number, let minimum):
      return "\(number) is below exclusive minimum value of \(minimum)"

    // String
    case .exceedsMaxLength(let string, let maxLength):
      return "String '\(string)' exceeds maximum length of \(maxLength)"
    case .belowMinLength(let string, let minLength):
      return "String '\(string)' is shorter than minimum length of \(minLength)"
    case .patternMismatch(let string, let pattern):
      return "String '\(string)' does not match pattern '\(pattern)'"
    case .invalidFormat(let name, let value):
      return "String '\(value)' is not valid for format '\(name)'"

    // Arrays
    case .exceedsMaxItems(let count, let maxItems):
      return "Array has \(count) items which exceeds maximum of \(maxItems)"
    case .belowMinItems(let count, let minItems):
      return "Array has \(count) items which is less than minimum of \(minItems)"
    case .itemsNotUnique:
      return "Array items are not unique as required"
    case .containsInsufficientMatches(let count, let required):
      return "Array contains \(count) matching items but requires at least \(required)"
    case .containsExcessiveMatches(let count, let maxAllowed):
      return "Array contains \(count) matching items which exceeds maximum allowed of \(maxAllowed)"
    case .invalidItem(let index, let error):
      return "Item at index \(index) failed validation: \(error.message)"

    // Objects
    case .exceedsMaxProperties(let count, let maxProperties):
      return "Object has \(count) properties which exceeds maximum of \(maxProperties)"
    case .belowMinProperties(let count, let minProperties):
      return "Object has \(count) properties which is less than minimum of \(minProperties)"
    case .missingRequiredProperty(let key):
      return "Required property '\(key)' is missing"
    case .missingDependentProperty(let key, let dependentOn):
      return "Property '\(key)' is missing, which is required when '\(dependentOn)' is present"
    case .invalidProperty(let key, let error):
      return "Property '\(key)' failed validation: \(error.message)"
    case .invalidPatternProperty(let key, let pattern):
      return "Property name '\(key)' does not match pattern '\(pattern)'"
    case .invalidAdditionalProperty(let key):
      return "Additional property '\(key)' is not allowed"

    // Logical
    case .allOfFailed(let errors):
      return "Failed to satisfy all schemas: \(errors.map { $0.message }.joined(separator: "; "))"
    case .anyOfFailed(let errors):
      return "Failed to satisfy any schema: \(errors.map { $0.message }.joined(separator: "; "))"
    case .oneOfFailed(let errors):
      return
        "Failed to satisfy exactly one schema: \(errors.map { $0.message }.joined(separator: "; "))"
    case .notFailed:
      return "Instance should not match the schema"

    // Conditional
    case .conditionalFailed(let condition, let errors):
      return
        "Failed conditional validation for '\(condition)': \(errors.map { $0.message }.joined(separator: "; "))"
    case .invalidDependentSchema(let key, let errors):
      return
        "Failed dependent schema validation for '\(key)': \(errors.map { $0.message }.joined(separator: "; "))"
    case .unevaluatedItemsFailed(let errors):
      return
        "Failed unevaluated items validation: \(errors.map { $0.message }.joined(separator: "; "))"
    case .unevaluatedPropertyFailed(let errors):
      return
        "Failed unevaluated properties validation: \(errors.map { $0.message }.joined(separator: "; "))"

    // Reference
    case .invalidReference(let ref):
      return "Invalid reference: \(ref)"
    case .referenceValidationFailure(let ref, let errors):
      return
        "Validation failed for reference '\(ref)': \(errors.map { $0.message }.joined(separator: "; "))"

    // General
    case .keywordFailure(let keyword, let errors):
      return
        "Validation failed for keyword '\(keyword)': \(errors.map { $0.message }.joined(separator: "; "))"
    }
  }
}
