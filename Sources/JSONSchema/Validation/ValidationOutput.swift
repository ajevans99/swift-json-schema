import Foundation

public enum ValidationOutputLevel: Hashable, Sendable {
  case flag
  case basic
  case detailed
  case verbose
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

  /// Convenience for producing the spec's "detailed" level output, which condenses the validation tree.
  public static let detailed = ValidationOutputConfiguration(level: .detailed)

  /// Convenience for producing the spec's "verbose" level output, which preserves the full validation tree.
  public static let verbose = ValidationOutputConfiguration(level: .verbose)
}

private struct ValidationOutputUnit: Encodable {
  let valid: Bool
  let keywordLocation: String
  let absoluteKeywordLocation: String?
  let instanceLocation: String
  let error: String?
  let errors: [ValidationOutputUnit]?
  let annotations: [AnyAnnotationWrapper]?

  static func makeBasic(from result: ValidationResult) -> ValidationOutputUnit {
    let flattenedErrors = flatten(errors: result.errors)

    return ValidationOutputUnit(
      valid: result.isValid,
      keywordLocation: result.keywordLocation.jsonPointerString,
      absoluteKeywordLocation: result.absoluteKeywordLocation,
      instanceLocation: result.instanceLocation.jsonPointerString,
      error: (result.isValid || flattenedErrors != nil) ? nil : basicFallbackMessage(for: result),
      errors: flattenedErrors,
      annotations: annotations(from: result)
    )
  }

  static func makeDetailed(from result: ValidationResult) -> ValidationOutputUnit {
    let verboseUnit = makeVerbose(from: result)
    return condense(verboseUnit, isRoot: true) ?? verboseUnit
  }

  static func makeVerbose(from result: ValidationResult) -> ValidationOutputUnit {
    let nestedErrors: [ValidationOutputUnit]? = {
      guard let errors = result.errors, !errors.isEmpty else { return nil }
      return errors.map { makeTree(from: $0) }
    }()

    return ValidationOutputUnit(
      valid: result.isValid,
      keywordLocation: result.keywordLocation.jsonPointerString,
      absoluteKeywordLocation: result.absoluteKeywordLocation,
      instanceLocation: result.instanceLocation.jsonPointerString,
      error: result.isValid || (nestedErrors != nil && !(nestedErrors?.isEmpty ?? true))
        ? nil
        : basicFallbackMessage(for: result),
      errors: nestedErrors,
      annotations: annotations(from: result)
    )
  }

  static func flatten(errors: [ValidationError]?) -> [ValidationOutputUnit]? {
    guard let errors, !errors.isEmpty else { return nil }

    var flattened: [ValidationOutputUnit] = []
    for error in errors {
      if let nested = error.errors, !nested.isEmpty {
        if let nestedFlattened = flatten(errors: nested) {
          flattened.append(contentsOf: nestedFlattened)
        }
      } else {
        flattened.append(leaf(from: error))
      }
    }

    return flattened.isEmpty ? nil : flattened
  }

  static func makeTree(from error: ValidationError) -> ValidationOutputUnit {
    guard let nested = error.errors, !nested.isEmpty else {
      return leaf(from: error)
    }
    let nestedUnits = nested.map { makeTree(from: $0) }
    return ValidationOutputUnit(
      valid: false,
      keywordLocation: error.keywordLocation.jsonPointerString,
      absoluteKeywordLocation: error.absoluteKeywordLocation,
      instanceLocation: error.instanceLocation.jsonPointerString,
      error: nil,
      errors: nestedUnits.isEmpty ? nil : nestedUnits,
      annotations: nil
    )
  }

  static func condense(_ unit: ValidationOutputUnit, isRoot: Bool) -> ValidationOutputUnit? {
    let condensedChildren =
      unit.errors?
      .compactMap { condense($0, isRoot: false) } ?? []
    let hasChildren = !condensedChildren.isEmpty
    let hasAnnotations = unit.annotations?.isEmpty == false
    let hasLocalInfo = unit.error != nil || hasAnnotations

    if !isRoot && !hasLocalInfo {
      if !hasChildren {
        return nil
      }

      if condensedChildren.count == 1 {
        return condensedChildren[0]
      }
    }

    return ValidationOutputUnit(
      valid: unit.valid,
      keywordLocation: unit.keywordLocation,
      absoluteKeywordLocation: unit.absoluteKeywordLocation,
      instanceLocation: unit.instanceLocation,
      error: unit.error,
      errors: hasChildren ? condensedChildren : nil,
      annotations: unit.annotations
    )
  }

  private static func annotations(from result: ValidationResult) -> [AnyAnnotationWrapper]? {
    guard result.isValid, let annotations = result.annotations, !annotations.isEmpty else {
      return nil
    }

    return annotations.map { AnyAnnotationWrapper(annotation: $0) }
  }

  private static func leaf(from error: ValidationError) -> ValidationOutputUnit {
    ValidationOutputUnit(
      valid: false,
      keywordLocation: error.keywordLocation.jsonPointerString,
      absoluteKeywordLocation: error.absoluteKeywordLocation,
      instanceLocation: error.instanceLocation.jsonPointerString,
      error: error.message,
      errors: nil,
      annotations: nil
    )
  }

  private static func basicFallbackMessage(for result: ValidationResult) -> String? {
    result.isValid ? nil : "Validation failed."
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
      return try ValidationOutputUnit.jsonValue(from: .makeBasic(from: self))
    case .detailed:
      return try ValidationOutputUnit.jsonValue(from: .makeDetailed(from: self))
    case .verbose:
      return try ValidationOutputUnit.jsonValue(from: .makeVerbose(from: self))
    }
  }

  public func renderedOutput(configuration: ValidationOutputConfiguration) throws -> JSONValue {
    try renderedOutput(level: configuration.level)
  }
}
