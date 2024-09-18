public typealias KeywordIdentifier = String

protocol Keyword: Sendable {
  /// The name of the keyword, such as `type` or `minLength`.
  static var name: KeywordIdentifier { get }

  var schema: JSONValue { get }
  var location: JSONPointer { get }
  var context: Context { get }

  init(schema: JSONValue, location: JSONPointer, context: Context)
}
