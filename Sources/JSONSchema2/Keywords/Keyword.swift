typealias KeywordIdentifier = String

protocol Keyword: Hashable {
  /// The name of the keyword, such as `type` or `minLength`.
  var name: KeywordIdentifier { get }

  /// A set of dialects that support this keyword.
  var supportedDialects: Set<Dialect> { get }
}

extension Keyword {
  var supportedDialects: Set<Dialect> { [.draft2020_12] }
}
