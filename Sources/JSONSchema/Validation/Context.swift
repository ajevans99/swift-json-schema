import Foundation

/// Container for information used when validating a schema.
public final class Context: Sendable {
  var dialect: Dialect

  var rootRawSchema: JSONValue?

  var identifierRegistry: [URL: JSONPointer] = [:]

  var remoteSchemaStorage: [String: JSONValue] = [:]
  var schemaCache = [String: Schema]()

  var anchors = [URL: JSONPointer]()

  var dynamicScopes: [[String: JSONPointer]] = []

  /// A dictionary that tracks whether the `minContains` constraint is effectively zero
  /// for specific schema locations.
  ///
  /// - Key: A `JSONPointer` representing the schema location. This pointer identifies
  ///   the specific part of the schema where the `minContains` constraint is applied.
  /// - Value: A `Bool` indicating whether the `minContains` constraint is considered zero
  ///   at the specified schema location. A value of `true` means that the constraint
  ///   is effectively zero, allowing for validation to pass even if no instances match
  ///   the `contains` keyword.
  var minContainsIsZero = [JSONPointer: Bool]()

  /// A dictionary that stores the results of conditional validations within a schema.
  ///
  /// - Key: A string representing the schema location pointer, excluding the specific
  ///   path to the "if", "else", or "then" conditions.
  /// - Value: An optional `ValidationResult` that represents the outcome of the
  ///   conditional validation at the specified schema location.
  var ifConditionalResults = [JSONPointer: ValidationResult]()

  public init(dialect: Dialect, remoteSchema: [String: JSONValue] = [:]) {
    self.dialect = dialect
    self.remoteSchemaStorage = remoteSchema
  }
}
