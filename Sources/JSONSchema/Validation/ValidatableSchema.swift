import Foundation

public protocol ValidatableSchema: Equatable, Sendable {
  func validate(_ instance: JSONValue, at location: JSONPointer) -> ValidationResult
}

extension ValidatableSchema {
  public func validate(_ instance: JSONValue) -> ValidationResult {
    self.validate(instance, at: .init())
  }

  /// Convenience for validating instances from `String` form. Uses
  /// ``JSONValue/parse(_:)`` (which preserves declared key order) so that
  /// the resulting validation output is deterministic across processes —
  /// `JSONDecoder` does not preserve key order, which would feed
  /// hash-randomized property order into the validation traversal and
  /// produce nondeterministic annotation/error sequences (see #149).
  public func validate(
    instance: String,
    at location: JSONPointer = .init()
  ) throws -> ValidationResult {
    let parsedInstance = try JSONValue.parse(instance)
    return validate(parsedInstance, at: location)
  }

  /// Validates the instance and renders the result into a spec-compliant validation output document.
  public func validate(
    _ instance: JSONValue,
    at location: JSONPointer = .init(),
    output configuration: ValidationOutputConfiguration
  ) throws -> JSONValue {
    let result = validate(instance, at: location)
    return try result.renderedOutput(configuration: configuration)
  }

  /// Convenience for producing validation outputs from `String` instances.
  /// Uses ``JSONValue/parse(_:)`` (key-order-preserving) for the same
  /// determinism reasons as ``validate(instance:at:)``.
  public func validate(
    instance: String,
    at location: JSONPointer = .init(),
    output configuration: ValidationOutputConfiguration
  ) throws -> JSONValue {
    let parsedInstance = try JSONValue.parse(instance)
    return try validate(parsedInstance, at: location, output: configuration)
  }
}
