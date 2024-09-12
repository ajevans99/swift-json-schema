typealias KeywordIdentifier = String

protocol Keyword: Hashable {
  /// The name of the keyword, such as `type` or `minLength`.
  static var name: KeywordIdentifier { get }

  var schema: JSONValue { get }
  var location: JSONPointer { get }

  init(schema: JSONValue, location: JSONPointer)
}

extension Keyword {
  var name: KeywordIdentifier {
    Self.name
  }
}
