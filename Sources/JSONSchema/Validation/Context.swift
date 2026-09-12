import Foundation

/// Reusable schema definitions, reference caches, and validation configuration.
///
/// Dynamic scopes are local to each evaluation, not shared by concurrent callers.
public final class Context: Sendable {
  private let lockedDialect: LockIsolated<Dialect>
  var dialect: Dialect {
    get { lockedDialect.withLock { $0 } }
    set { lockedDialect.withLock { $0 = newValue } }
  }

  var rootRawSchema: JSONValue? {
    registry.withLock { $0.rootRawSchema }
  }

  /// Identifies where a `$id` lives: which document and what JSON pointer inside it.
  struct IdentifierLocation: Sendable {
    let document: URL
    let pointer: JSONPointer
  }

  var identifierRegistry: [URL: IdentifierLocation] {
    registry.withLock { $0.identifiers }
  }

  /// Cache of every raw schema document we've loaded, keyed by canonical document URL.
  var documentCache: [URL: SchemaDocument] {
    registry.withLock { $0.documents }
  }

  /// Per-document map of `$dynamicAnchor` names to their location and base URI.
  var documentDynamicAnchors: [URL: [String: (pointer: JSONPointer, baseURI: URL)]] {
    registry.withLock { $0.dynamicAnchors }
  }

  private let lockedRemoteSchemaStorage: LockIsolated<[String: JSONValue]>
  var remoteSchemaStorage: [String: JSONValue] {
    get { lockedRemoteSchemaStorage.withLock { $0 } }
    set { lockedRemoteSchemaStorage.withLock { $0 = newValue } }
  }

  var schemaCache: [String: Schema] {
    registry.withLock { $0.schemas }
  }

  var anchors: [URL: JSONPointer] {
    registry.withLock { $0.anchors }
  }

  typealias DynamicScope = [String: (document: URL, pointer: JSONPointer, baseURI: URL)]

  @TaskLocal private static var evaluationScopes: [ObjectIdentifier: [DynamicScope]] = [:]
  @TaskLocal private static var vocabularyScopes: [ObjectIdentifier: Set<String>] = [:]

  var dynamicScopes: [DynamicScope] {
    Self.evaluationScopes[ObjectIdentifier(self)] ?? []
  }

  static func withFreshEvaluation<Result>(_ operation: () -> Result) -> Result {
    $evaluationScopes.withValue([:], operation: operation)
  }

  func withDynamicScopes<Result>(_ scopes: [DynamicScope], operation: () -> Result) -> Result {
    var evaluations = Self.evaluationScopes
    evaluations[ObjectIdentifier(self), default: []].append(contentsOf: scopes)
    return Self.$evaluationScopes.withValue(evaluations, operation: operation)
  }

  /// Validators used when the ``Keywords.Format`` keyword is present.
  private let lockedFormatValidators: LockIsolated<[String: any FormatValidator]>
  var formatValidators: [String: any FormatValidator] {
    get { lockedFormatValidators.withLock { $0 } }
    set { lockedFormatValidators.withLock { $0 = newValue } }
  }

  /// Set of active vocabularies that should be applied when creating schemas.
  /// If nil, all dialect keywords are available. If set, only keywords from
  /// these vocabularies will be processed.
  var activeVocabularies: Set<String>? {
    Self.vocabularyScopes[ObjectIdentifier(self)]
  }

  func withActiveVocabularies<Result>(
    _ vocabularies: Set<String>?,
    operation: () -> Result
  ) -> Result {
    var scopes = Self.vocabularyScopes
    scopes[ObjectIdentifier(self)] = vocabularies
    return Self.$vocabularyScopes.withValue(scopes, operation: operation)
  }

  private struct Registry: Sendable {
    var rootRawSchema: JSONValue?
    var identifiers: [URL: IdentifierLocation] = [:]
    var documents: [URL: SchemaDocument] = [:]
    var dynamicAnchors: [URL: [String: (pointer: JSONPointer, baseURI: URL)]] = [:]
    var schemas: [String: Schema] = [:]
    var anchors: [URL: JSONPointer] = [:]
  }

  private let registry = LockIsolated(Registry())

  func registerDocument(_ rawSchema: JSONValue, at url: URL) {
    registry.withLock {
      if $0.rootRawSchema == nil { $0.rootRawSchema = rawSchema }
      if $0.documents[url] == nil {
        $0.documents[url] = SchemaDocument(url: url, rawSchema: rawSchema)
      }
    }
  }

  func registerIdentifier(_ url: URL, location: IdentifierLocation) {
    let resourceURL = url.withoutFragment ?? url
    registry.withLock {
      guard $0.identifiers[url] == nil else { return }
      $0.identifiers[url] = location
      if $0.documents[resourceURL] == nil, let document = $0.documents[location.document] {
        $0.documents[resourceURL] = SchemaDocument(
          url: resourceURL,
          rawSchema: document.rawSchema
        )
      }
    }
  }

  func registerAnchor(_ url: URL, at location: JSONPointer) {
    registry.withLock {
      if $0.anchors[url] == nil { $0.anchors[url] = location }
    }
  }

  func registerDynamicAnchor(_ name: String, at location: JSONPointer, baseURI: URL) {
    let document = baseURI.withoutFragment ?? baseURI
    registry.withLock {
      if $0.dynamicAnchors[document]?[name] == nil {
        $0.dynamicAnchors[document, default: [:]][name] = (location, baseURI)
      }
    }
  }

  func cacheSchema(_ schema: Schema, at uri: String) {
    registry.withLock { $0.schemas[uri] = schema }
  }

  public init(
    dialect: Dialect,
    remoteSchema: [String: JSONValue] = [:],
    formatValidators: [any FormatValidator] = []
  ) {
    self.lockedDialect = LockIsolated(dialect)
    self.lockedRemoteSchemaStorage = LockIsolated(remoteSchema)
    self.lockedFormatValidators = LockIsolated(
      Dictionary(uniqueKeysWithValues: formatValidators.map { ($0.formatName, $0) })
    )
  }

  package func independentContext() -> Context {
    Context(
      dialect: dialect,
      remoteSchema: remoteSchemaStorage,
      formatValidators: Array(formatValidators.values)
    )
  }

  package var hasStandardProjectionVocabulary: Bool {
    guard let vocabulary = remoteSchemaStorage[dialect.rawValue]?.object?["$vocabulary"] else {
      return true
    }
    guard let entries = vocabulary.object else { return false }
    return Set(entries.keys) == dialect.supportedVocabularies
      && entries.values.allSatisfy { $0.boolean != nil }
  }
}
