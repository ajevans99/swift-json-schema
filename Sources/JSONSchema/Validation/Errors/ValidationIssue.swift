import Foundation

/// A single reason a keyword rejected an instance.
///
/// Issues are identified by a stable ``Code`` rather than an enum case, so new built-in codes
/// and custom keyword or format codes can be added without breaking source compatibility.
/// Built-in issues are created with the static factories (for example
/// ``patternMismatch(string:pattern:)``) and can be matched with `issue.code == .patternMismatch`.
/// Applications can define their own codes and construct issues with
/// ``init(code:message:payload:errors:)``. Public validators such as `FormatValidator` currently
/// report only pass/fail, so custom codes are not yet surfaced by `Schema.validate`; the struct
/// shape lets future hooks and built-in codes be added without another breaking change.
public struct ValidationIssue: Error, Codable, Equatable, Sendable {
  /// A stable, string-backed identifier for a kind of validation issue.
  public struct Code: RawRepresentable, Hashable, Codable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible
  {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public init(from decoder: any Decoder) throws {
      rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(rawValue)
    }

    public var description: String { rawValue }
  }

  /// Identifies the kind of issue.
  public let code: Code
  /// A human-readable description of the issue.
  public let message: String
  /// Structured details about the failure, such as the offending value or limit.
  public let payload: [String: JSONValue]
  /// Nested validation errors, for issues produced by applicators and references.
  public let errors: [ValidationError]

  public init(
    code: Code,
    message: String,
    payload: [String: JSONValue] = [:],
    errors: [ValidationError] = []
  ) {
    self.code = code
    self.message = message
    self.payload = payload
    self.errors = errors
  }
}

extension ValidationIssue: CustomStringConvertible {
  public var description: String { message }
}

extension ValidationIssue.Code {
  public static let typeMismatch: Self = "typeMismatch"
  public static let notEnumCase: Self = "notEnumCase"
  public static let constantMismatch: Self = "constantMismatch"

  // Number
  public static let notMultipleOf: Self = "notMultipleOf"
  public static let exceedsMaximum: Self = "exceedsMaximum"
  public static let exceedsExclusiveMaximum: Self = "exceedsExclusiveMaximum"
  public static let belowMinimum: Self = "belowMinimum"
  public static let belowExclusiveMinimum: Self = "belowExclusiveMinimum"
  public static let numericValidationFailure: Self = "numericValidationFailure"
  public static let evaluationFailed: Self = "evaluationFailed"

  // String
  public static let exceedsMaxLength: Self = "exceedsMaxLength"
  public static let belowMinLength: Self = "belowMinLength"
  public static let patternMismatch: Self = "patternMismatch"
  public static let invalidPattern: Self = "invalidPattern"
  public static let invalidFormat: Self = "invalidFormat"

  // Arrays
  public static let exceedsMaxItems: Self = "exceedsMaxItems"
  public static let belowMinItems: Self = "belowMinItems"
  public static let itemsNotUnique: Self = "itemsNotUnique"
  public static let containsInsufficientMatches: Self = "containsInsufficientMatches"
  public static let containsExcessiveMatches: Self = "containsExcessiveMatches"
  public static let invalidItem: Self = "invalidItem"

  // Objects
  public static let exceedsMaxProperties: Self = "exceedsMaxProperties"
  public static let belowMinProperties: Self = "belowMinProperties"
  public static let missingRequiredProperty: Self = "missingRequiredProperty"
  public static let missingDependentProperty: Self = "missingDependentProperty"
  public static let invalidProperty: Self = "invalidProperty"
  public static let invalidPatternProperty: Self = "invalidPatternProperty"
  public static let invalidAdditionalProperty: Self = "invalidAdditionalProperty"

  // Logical
  public static let allOfFailed: Self = "allOfFailed"
  public static let anyOfFailed: Self = "anyOfFailed"
  public static let oneOfFailed: Self = "oneOfFailed"
  public static let notFailed: Self = "notFailed"

  // Conditional
  public static let conditionalFailed: Self = "conditionalFailed"
  public static let invalidDependentSchema: Self = "invalidDependentSchema"
  public static let unevaluatedItemsFailed: Self = "unevaluatedItemsFailed"
  public static let unevaluatedPropertyFailed: Self = "unevaluatedPropertyFailed"

  // Reference
  public static let invalidReference: Self = "invalidReference"
  public static let referenceValidationFailure: Self = "referenceValidationFailure"

  public static let keywordFailure: Self = "keywordFailure"
}

private func joined(_ errors: [ValidationError]) -> String {
  errors.map { $0.message }.joined(separator: "; ")
}

extension ValidationIssue {
  // General
  public static func typeMismatch(expected: [JSONType], actual: JSONType) -> Self {
    .init(
      code: .typeMismatch,
      message: "Expected type '\(expected)' but found '\(actual)'",
      payload: [
        "expected": .array(expected.map { .string($0.rawValue) }),
        "actual": .string(actual.rawValue),
      ]
    )
  }

  public static func notEnumCase(value: JSONValue, allowedValues: [JSONValue]) -> Self {
    .init(
      code: .notEnumCase,
      message:
        "'\(value)' is not one of the allowed values: \(allowedValues.map(\.description).joined(separator: ", "))",
      payload: ["value": value, "allowedValues": .array(allowedValues)]
    )
  }

  public static func constantMismatch(expected: JSONValue, actual: JSONValue) -> Self {
    .init(
      code: .constantMismatch,
      message: "Expected constant value '\(expected)' but found '\(actual)'",
      payload: ["expected": expected, "actual": actual]
    )
  }

  // Number
  public static func notMultipleOf(number: JSONNumberLiteral, multiple: JSONNumberLiteral) -> Self {
    .init(
      code: .notMultipleOf,
      message: "\(number) is not a multiple of \(multiple)",
      payload: ["number": .numberLiteral(number), "multiple": .numberLiteral(multiple)]
    )
  }

  public static func exceedsMaximum(number: JSONNumberLiteral, maximum: JSONNumberLiteral) -> Self {
    .init(
      code: .exceedsMaximum,
      message: "\(number) exceeds maximum value of \(maximum)",
      payload: ["number": .numberLiteral(number), "maximum": .numberLiteral(maximum)]
    )
  }

  public static func exceedsExclusiveMaximum(
    number: JSONNumberLiteral,
    maximum: JSONNumberLiteral
  ) -> Self {
    .init(
      code: .exceedsExclusiveMaximum,
      message: "\(number) exceeds exclusive maximum value of \(maximum)",
      payload: ["number": .numberLiteral(number), "maximum": .numberLiteral(maximum)]
    )
  }

  public static func belowMinimum(number: JSONNumberLiteral, minimum: JSONNumberLiteral) -> Self {
    .init(
      code: .belowMinimum,
      message: "\(number) is below minimum value of \(minimum)",
      payload: ["number": .numberLiteral(number), "minimum": .numberLiteral(minimum)]
    )
  }

  public static func belowExclusiveMinimum(
    number: JSONNumberLiteral,
    minimum: JSONNumberLiteral
  ) -> Self {
    .init(
      code: .belowExclusiveMinimum,
      message: "\(number) is below exclusive minimum value of \(minimum)",
      payload: ["number": .numberLiteral(number), "minimum": .numberLiteral(minimum)]
    )
  }

  public static func numericValidationFailure(reason: String) -> Self {
    .init(code: .numericValidationFailure, message: reason, payload: ["reason": .string(reason)])
  }

  public static func evaluationFailed(errors: [ValidationError]) -> Self {
    .init(
      code: .evaluationFailed,
      message: "Schema evaluation could not be completed",
      errors: errors
    )
  }

  // String
  public static func exceedsMaxLength(string: String, maxLength: Int) -> Self {
    .init(
      code: .exceedsMaxLength,
      message: "String '\(string)' exceeds maximum length of \(maxLength)",
      payload: ["string": .string(string), "maxLength": .integer(maxLength)]
    )
  }

  public static func belowMinLength(string: String, minLength: Int) -> Self {
    .init(
      code: .belowMinLength,
      message: "String '\(string)' is shorter than minimum length of \(minLength)",
      payload: ["string": .string(string), "minLength": .integer(minLength)]
    )
  }

  public static func patternMismatch(string: String, pattern: String) -> Self {
    .init(
      code: .patternMismatch,
      message: "String '\(string)' does not match pattern '\(pattern)'",
      payload: ["string": .string(string), "pattern": .string(pattern)]
    )
  }

  public static func invalidPattern(pattern: String) -> Self {
    .init(
      code: .invalidPattern,
      message: "Pattern '\(pattern)' is not a valid regular expression",
      payload: ["pattern": .string(pattern)]
    )
  }

  public static func invalidFormat(name: String, value: String) -> Self {
    .init(
      code: .invalidFormat,
      message: "String '\(value)' is not valid for format '\(name)'",
      payload: ["name": .string(name), "value": .string(value)]
    )
  }

  // Arrays
  public static func exceedsMaxItems(count: Int, maxItems: Int) -> Self {
    .init(
      code: .exceedsMaxItems,
      message: "Array has \(count) items which exceeds maximum of \(maxItems)",
      payload: ["count": .integer(count), "maxItems": .integer(maxItems)]
    )
  }

  public static func belowMinItems(count: Int, minItems: Int) -> Self {
    .init(
      code: .belowMinItems,
      message: "Array has \(count) items which is less than minimum of \(minItems)",
      payload: ["count": .integer(count), "minItems": .integer(minItems)]
    )
  }

  public static var itemsNotUnique: Self {
    .init(code: .itemsNotUnique, message: "Array items are not unique as required")
  }

  public static func containsInsufficientMatches(count: Int, required: Int) -> Self {
    .init(
      code: .containsInsufficientMatches,
      message: "Array contains \(count) matching items but requires at least \(required)",
      payload: ["count": .integer(count), "required": .integer(required)]
    )
  }

  public static func containsExcessiveMatches(count: Int, maxAllowed: Int) -> Self {
    .init(
      code: .containsExcessiveMatches,
      message:
        "Array contains \(count) matching items which exceeds maximum allowed of \(maxAllowed)",
      payload: ["count": .integer(count), "maxAllowed": .integer(maxAllowed)]
    )
  }

  public static func invalidItem(index: Int, error: ValidationError) -> Self {
    .init(
      code: .invalidItem,
      message: "Item at index \(index) failed validation: \(error.message)",
      payload: ["index": .integer(index)],
      errors: [error]
    )
  }

  // Objects
  public static func exceedsMaxProperties(count: Int, maxProperties: Int) -> Self {
    .init(
      code: .exceedsMaxProperties,
      message: "Object has \(count) properties which exceeds maximum of \(maxProperties)",
      payload: ["count": .integer(count), "maxProperties": .integer(maxProperties)]
    )
  }

  public static func belowMinProperties(count: Int, minProperties: Int) -> Self {
    .init(
      code: .belowMinProperties,
      message: "Object has \(count) properties which is less than minimum of \(minProperties)",
      payload: ["count": .integer(count), "minProperties": .integer(minProperties)]
    )
  }

  public static func missingRequiredProperty(key: String) -> Self {
    .init(
      code: .missingRequiredProperty,
      message: "Required property '\(key)' is missing",
      payload: ["key": .string(key)]
    )
  }

  public static func missingDependentProperty(key: String, dependentOn: String) -> Self {
    .init(
      code: .missingDependentProperty,
      message: "Property '\(key)' is missing, which is required when '\(dependentOn)' is present",
      payload: ["key": .string(key), "dependentOn": .string(dependentOn)]
    )
  }

  public static func invalidProperty(key: String, error: ValidationError) -> Self {
    .init(
      code: .invalidProperty,
      message: "Property '\(key)' failed validation: \(error.message)",
      payload: ["key": .string(key)],
      errors: [error]
    )
  }

  public static func invalidPatternProperty(key: String, pattern: String) -> Self {
    .init(
      code: .invalidPatternProperty,
      message: "Property name '\(key)' does not match pattern '\(pattern)'",
      payload: ["key": .string(key), "pattern": .string(pattern)]
    )
  }

  public static func invalidAdditionalProperty(key: String) -> Self {
    .init(
      code: .invalidAdditionalProperty,
      message: "Additional property '\(key)' is not allowed",
      payload: ["key": .string(key)]
    )
  }

  // Logical
  public static func allOfFailed(errors: [ValidationError]) -> Self {
    .init(
      code: .allOfFailed,
      message: "Failed to satisfy all schemas: \(joined(errors))",
      errors: errors
    )
  }

  public static func anyOfFailed(errors: [ValidationError]) -> Self {
    .init(
      code: .anyOfFailed,
      message: "Failed to satisfy any schema: \(joined(errors))",
      errors: errors
    )
  }

  public static func oneOfFailed(errors: [ValidationError]) -> Self {
    .init(
      code: .oneOfFailed,
      message: "Failed to satisfy exactly one schema: \(joined(errors))",
      errors: errors
    )
  }

  public static var notFailed: Self {
    .init(code: .notFailed, message: "Instance should not match the schema")
  }

  // Conditional
  public static func conditionalFailed(condition: String, errors: [ValidationError]) -> Self {
    .init(
      code: .conditionalFailed,
      message: "Failed conditional validation for '\(condition)': \(joined(errors))",
      payload: ["condition": .string(condition)],
      errors: errors
    )
  }

  public static func invalidDependentSchema(key: String, errors: [ValidationError]) -> Self {
    .init(
      code: .invalidDependentSchema,
      message: "Failed dependent schema validation for '\(key)': \(joined(errors))",
      payload: ["key": .string(key)],
      errors: errors
    )
  }

  public static func unevaluatedItemsFailed(errors: [ValidationError]) -> Self {
    .init(
      code: .unevaluatedItemsFailed,
      message: "Failed unevaluated items validation: \(joined(errors))",
      errors: errors
    )
  }

  public static func unevaluatedPropertyFailed(errors: [ValidationError]) -> Self {
    .init(
      code: .unevaluatedPropertyFailed,
      message: "Failed unevaluated properties validation: \(joined(errors))",
      errors: errors
    )
  }

  // Reference
  public static func invalidReference(_ ref: String) -> Self {
    .init(
      code: .invalidReference,
      message: "Invalid reference: \(ref)",
      payload: ["ref": .string(ref)]
    )
  }

  public static func referenceValidationFailure(ref: String, errors: [ValidationError]) -> Self {
    .init(
      code: .referenceValidationFailure,
      message: "Validation failed for reference '\(ref)': \(joined(errors))",
      payload: ["ref": .string(ref)],
      errors: errors
    )
  }

  public static func keywordFailure(keyword: KeywordIdentifier, errors: [ValidationError]) -> Self {
    .init(
      code: .keywordFailure,
      message: "Validation failed for keyword '\(keyword)': \(joined(errors))",
      payload: ["keyword": .string(keyword)],
      errors: errors
    )
  }
}

extension ValidationIssue {
  var isEvaluationFailure: Bool {
    code == .numericValidationFailure || code == .evaluationFailed
  }

  func makeValidationError(
    keyword: String,
    keywordLocation: JSONPointer,
    absoluteKeywordLocation: URL?,
    instanceLocation: JSONPointer
  ) -> ValidationError {
    let nested = errors.isEmpty ? nil : errors
    if code == .keywordFailure, let name = payload["keyword"]?.string {
      return .init(
        keyword: name,
        message: "Validation failed for keyword '\(name)'",
        keywordLocation: keywordLocation,
        absoluteKeywordLocation: absoluteKeywordLocation,
        instanceLocation: instanceLocation,
        errors: nested
      )
    }
    if code == .referenceValidationFailure, let ref = payload["ref"]?.string {
      return .init(
        keyword: keyword,
        message: "Validation failed during reference validation '\(ref)'",
        keywordLocation: keywordLocation,
        absoluteKeywordLocation: absoluteKeywordLocation,
        instanceLocation: instanceLocation,
        errors: nested
      )
    }
    return .init(
      keyword: keyword,
      message: message,
      keywordLocation: keywordLocation,
      absoluteKeywordLocation: absoluteKeywordLocation,
      instanceLocation: instanceLocation,
      errors: nested
    )
  }
}
