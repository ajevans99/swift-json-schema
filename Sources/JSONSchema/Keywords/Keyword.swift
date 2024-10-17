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
}
