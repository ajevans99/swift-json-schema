import Foundation

/// Container for information used when validating a schema.
public final class Context: Sendable {
  var dialect: Dialect
  var baseURI: URL?

  var rootRawSchema: JSONValue?
  var validationStack = Set<JSONPointer>()

  var definitions = [String: Schema]()
  var dynamicAnchors = [String: JSONPointer]()

  // TODO: This probably needs to be scoped to location
  var ifConditionalResult: ValidationResult?

  init(dialect: Dialect) {
    self.dialect = dialect
  }

  static func == (lhs: Context, rhs: Context) -> Bool {
    lhs.dialect == rhs.dialect && lhs.rootRawSchema == rhs.rootRawSchema
  }
}