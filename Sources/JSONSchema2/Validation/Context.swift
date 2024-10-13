import Foundation

/// Container for information used when validating a schema.
public final class Context: Sendable {
  var dialect: Dialect

  var rootRawSchema: JSONValue?
  var validationStack = [String]()

  var identifierRegistry: [URL: JSONPointer] = [:]

  var remoteSchemaStorage: [String: JSONValue] = [:]
  var schemaCache = [String: Schema]()

  var anchors = [URL: JSONPointer]()
  var dynamicAnchors = [URL: JSONPointer]()

  // TODO: This probably needs to be scoped to location
  var minContainsIsZero: Bool = false
  var ifConditionalResult: ValidationResult?

  public init(dialect: Dialect, remoteSchema: [String: JSONValue] = [:]) {
    self.dialect = dialect
    self.remoteSchemaStorage = remoteSchema
  }

  static func == (lhs: Context, rhs: Context) -> Bool {
    lhs.dialect == rhs.dialect && lhs.rootRawSchema == rhs.rootRawSchema
  }
}
