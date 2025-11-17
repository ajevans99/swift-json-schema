import Foundation

/// Container for information used when validating a schema.
public final class Context: Sendable {
  private let lockedDialect: LockIsolated<Dialect>
  var dialect: Dialect {
    get { lockedDialect.withLock { $0 } }
    set { lockedDialect.withLock { $0 = newValue } }
  }

  private let lockedRootRawSchema: LockIsolated<JSONValue?>
  var rootRawSchema: JSONValue? {
    get { lockedRootRawSchema.withLock { $0 } }
    set { lockedRootRawSchema.withLock { $0 = newValue } }
  }

  /// Identifies where a `$id` lives: which document and what JSON pointer inside it.
  struct IdentifierLocation: Sendable {
    let document: URL
    let pointer: JSONPointer
  }

  private let lockedIdentifierRegistry: LockIsolated<[URL: IdentifierLocation]>
  var identifierRegistry: [URL: IdentifierLocation] {
    get { lockedIdentifierRegistry.withLock { $0 } }
    set { lockedIdentifierRegistry.withLock { $0 = newValue } }
  }

  /// Cache of every raw schema document we've loaded, keyed by canonical document URL.
  private let lockedDocumentCache: LockIsolated<[URL: SchemaDocument]>
  var documentCache: [URL: SchemaDocument] {
    get { lockedDocumentCache.withLock { $0 } }
    set { lockedDocumentCache.withLock { $0 = newValue } }
  }

  /// Per-document map of `$dynamicAnchor` names to their location and base URI.
  private let lockedDocumentDynamicAnchors: LockIsolated<
    [URL: [String: (pointer: JSONPointer, baseURI: URL)]]
  >
  var documentDynamicAnchors: [URL: [String: (pointer: JSONPointer, baseURI: URL)]] {
    get { lockedDocumentDynamicAnchors.withLock { $0 } }
    set { lockedDocumentDynamicAnchors.withLock { $0 = newValue } }
  }

  private let lockedRemoteSchemaStorage: LockIsolated<[String: JSONValue]>
  var remoteSchemaStorage: [String: JSONValue] {
    get { lockedRemoteSchemaStorage.withLock { $0 } }
    set { lockedRemoteSchemaStorage.withLock { $0 = newValue } }
  }

  private let lockedSchemaCache: LockIsolated<[String: Schema]>
  var schemaCache: [String: Schema] {
    get { lockedSchemaCache.withLock { $0 } }
    set { lockedSchemaCache.withLock { $0 = newValue } }
  }

  private let lockedAnchors: LockIsolated<[URL: JSONPointer]>
  var anchors: [URL: JSONPointer] {
    get { lockedAnchors.withLock { $0 } }
    set { lockedAnchors.withLock { $0 = newValue } }
  }

  /// Stack of dynamic scopes used to resolve ``$dynamicRef`` references.
  /// Each scope maps an anchor name to the schema location pointer and its
  /// associated base URI.
  /// Stack of `$dynamicScope`s used during validation; each push records the
  /// active anchors for the current schema/document so `$dynamicRef` can walk outwards.
  private let lockedDynamicScopes: LockIsolated<
    [[String: (document: URL, pointer: JSONPointer, baseURI: URL)]]
  >
  var dynamicScopes: [[String: (document: URL, pointer: JSONPointer, baseURI: URL)]] {
    get { lockedDynamicScopes.withLock { $0 } }
    set { lockedDynamicScopes.withLock { $0 = newValue } }
  }

  /// Validators used when the ``Keywords.Format`` keyword is present.
  private let lockedFormatValidators: LockIsolated<[String: any FormatValidator]>
  var formatValidators: [String: any FormatValidator] {
    get { lockedFormatValidators.withLock { $0 } }
    set { lockedFormatValidators.withLock { $0 = newValue } }
  }

  /// A dictionary that tracks whether the `minContains` constraint is effectively zero
  /// for specific schema locations.
  ///
  /// - Key: A `JSONPointer` representing the schema location. This pointer identifies
  ///   the specific part of the schema where the `minContains` constraint is applied.
  /// - Value: A `Bool` indicating whether the `minContains` constraint is considered zero
  ///   at the specified schema location. A value of `true` means that the constraint
  ///   is effectively zero, allowing for validation to pass even if no instances match
  ///   the `contains` keyword.
  private let lockedMinContainsIsZero: LockIsolated<[JSONPointer: Bool]>
  var minContainsIsZero: [JSONPointer: Bool] {
    get { lockedMinContainsIsZero.withLock { $0 } }
    set { lockedMinContainsIsZero.withLock { $0 = newValue } }
  }

  /// A dictionary that stores the results of conditional validations within a schema.
  ///
  /// - Key: A string representing the schema location pointer, excluding the specific
  ///   path to the "if", "else", or "then" conditions.
  /// - Value: An optional `ValidationResult` that represents the outcome of the
  ///   conditional validation at the specified schema location.
  private let lockedIfConditionalResults: LockIsolated<[JSONPointer: ValidationResult]>
  var ifConditionalResults: [JSONPointer: ValidationResult] {
    get { lockedIfConditionalResults.withLock { $0 } }
    set { lockedIfConditionalResults.withLock { $0 = newValue } }
  }

  /// Set of active vocabularies that should be applied when creating schemas.
  /// If nil, all dialect keywords are available. If set, only keywords from
  /// these vocabularies will be processed.
  private let lockedActiveVocabularies: LockIsolated<Set<String>?>
  var activeVocabularies: Set<String>? {
    get { lockedActiveVocabularies.withLock { $0 } }
    set { lockedActiveVocabularies.withLock { $0 = newValue } }
  }

  public init(
    dialect: Dialect,
    remoteSchema: [String: JSONValue] = [:],
    formatValidators: [any FormatValidator] = []
  ) {
    self.lockedDialect = LockIsolated(dialect)
    self.lockedRootRawSchema = LockIsolated(nil)
    self.lockedIdentifierRegistry = LockIsolated([:])
    self.lockedDocumentCache = LockIsolated([:])
    self.lockedDocumentDynamicAnchors = LockIsolated([:])
    self.lockedRemoteSchemaStorage = LockIsolated(remoteSchema)
    self.lockedSchemaCache = LockIsolated([:])
    self.lockedAnchors = LockIsolated([:])
    self.lockedDynamicScopes = LockIsolated([])
    self.lockedFormatValidators = LockIsolated(
      Dictionary(uniqueKeysWithValues: formatValidators.map { ($0.formatName, $0) })
    )
    self.lockedMinContainsIsZero = LockIsolated([:])
    self.lockedIfConditionalResults = LockIsolated([:])
    self.lockedActiveVocabularies = LockIsolated(nil)
  }
}
