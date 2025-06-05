import Foundation

/// Container for information used when validating a schema.
public final class Context: Sendable {
  var dialect: Dialect

  var rootRawSchema: JSONValue?

  var identifierRegistry: [URL: JSONPointer] = [:]

  var remoteSchemaStorage: [String: JSONValue] = [:]
  var schemaCache = [String: Schema]()

  var anchors = [URL: JSONPointer]()

  /// Stack of dynamic scopes used to resolve ``$dynamicRef`` references.
  /// Each scope maps an anchor name to the schema location pointer and its
  /// associated base URI.
  var dynamicScopes: [[String: (pointer: JSONPointer, baseURI: URL)]] = []

  /// Validators used when the ``Keywords.Format`` keyword is present.
  var formatValidators: [String: any FormatValidator] = [:]

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

  public init(
    dialect: Dialect,
    remoteSchema: [String: JSONValue] = [:],
    formatValidators: [any FormatValidator] = []
  ) {
    self.dialect = dialect
    self.remoteSchemaStorage = remoteSchema
    self.formatValidators = Dictionary(
      uniqueKeysWithValues: formatValidators.map { ($0.formatName, $0) }
    )
  }
}
