import Foundation

public typealias KeywordIdentifier = String

package protocol Keyword: Sendable {
  /// The name of the keyword, such as `type` or `minLength`.
  static var name: KeywordIdentifier { get }

  var value: JSONValue { get }
  var context: KeywordContext { get }

  init(value: JSONValue, context: KeywordContext)
}

package struct KeywordContext {
  let location: JSONPointer
  let context: Context
  let uri: URL

  package init(
    location: JSONPointer = .init(),
    context: Context = .init(dialect: .draft2020_12),
    uri: URL = .init(fileURLWithPath: #file)
  ) {
    self.location = location
    self.context = context
    self.uri = uri
  }
}
