import Foundation

/// Container for information used when validating a schema.
public final class Context: Sendable {
  var dialect: Dialect

  var rootRawSchema: JSONValue?
  var validationStack = Set<String>()

  var identifierRegistry: [URL: JSONPointer] = [:]

  var remoteSchemaStorage: [String: JSONValue] = [:]
  var schemaCache = [String: Schema]()

  var anchors = [String: JSONPointer]()
  var dynamicAnchors = [String: JSONPointer]()

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

  func resolveInternalReference(_ uri: URL, location: JSONPointer) throws(ValidationIssue) -> Schema? {
    guard let fragment = uri.fragment(percentEncoded: false) else {
      return nil
    }

    let pointer = anchors[fragment]?.dropLast() ?? JSONPointer(from: fragment)
    guard let value = rootRawSchema?.value(at: pointer) else {
      return nil
    }
    return try? Schema(rawSchema: value, location: location, context: self)
  }
}
