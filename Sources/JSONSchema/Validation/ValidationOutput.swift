import Foundation

public enum ValidationOutputLevel: Sendable {
  case flag
  case basic
}

public struct ValidationOutputConfiguration: Sendable, Equatable {
  public var level: ValidationOutputLevel

  public init(level: ValidationOutputLevel) {
    self.level = level
  }

  /// Convenience for producing the spec's "flag" level output, which is a boolean result.
  public static let flag = ValidationOutputConfiguration(level: .flag)

  /// Convenience for producing the spec's "basic" level output, which is a single result object.
  public static let basic = ValidationOutputConfiguration(level: .basic)
}

private struct ValidationOutputUnit: Encodable {
  let valid: Bool
  let keywordLocation: String
  let absoluteKeywordLocation: String?
  let instanceLocation: String
  let error: String?
  let errors: [ValidationOutputUnit]?
  let annotations: [AnyAnnotationWrapper]?

  static func make(from result: ValidationResult) -> ValidationOutputUnit {
    ValidationOutputUnit(
      valid: result.isValid,
      keywordLocation: result.keywordLocation.jsonPointerString,
      absoluteKeywordLocation: result.absoluteKeywordLocation,
      instanceLocation: result.instanceLocation.jsonPointerString,
      error: nil,
      errors: flatten(errors: result.errors),
      annotations: result.isValid
        ? result.annotations?.map { AnyAnnotationWrapper(annotation: $0) }
        : nil
    )
  }

  static func flatten(errors: [ValidationError]?) -> [ValidationOutputUnit]? {
    guard let errors else { return nil }

    var flattened: [ValidationOutputUnit] = []
    for error in errors {
      if let nested = error.errors, !nested.isEmpty {
        if let nestedFlattened = flatten(errors: nested) {
          flattened.append(contentsOf: nestedFlattened)
        }
      } else {
        flattened.append(
          ValidationOutputUnit(
            valid: false,
            keywordLocation: error.keywordLocation.jsonPointerString,
            absoluteKeywordLocation: error.absoluteKeywordLocation,
            instanceLocation: error.instanceLocation.jsonPointerString,
            error: error.message,
            errors: nil,
            annotations: nil
          )
        )
      }
    }

    return flattened.isEmpty ? nil : flattened
  }

  static func jsonValue(from unit: ValidationOutputUnit) throws -> JSONValue {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(unit)
    return try JSONDecoder().decode(JSONValue.self, from: data)
  }
}

extension ValidationResult {
  public func renderedOutput(level: ValidationOutputLevel) throws -> JSONValue {
    switch level {
    case .flag:
      return .boolean(isValid)
    case .basic:
      return try ValidationOutputUnit.jsonValue(from: .make(from: self))
    }
  }

  public func renderedOutput(configuration: ValidationOutputConfiguration) throws -> JSONValue {
    try renderedOutput(level: configuration.level)
  }
}
