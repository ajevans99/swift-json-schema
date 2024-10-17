/// Namespace for `Keyword` definitions.
package enum Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-schema-keyword
  struct SchemaKeyword: Keyword {
    static let name = "$schema"

    let value: JSONValue
    let context: KeywordContext

    func processIdentifier(into context: inout Context) { context.dialect = .draft2020_12 }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-vocabulary-keyword
  struct Vocabulary: Keyword {
    static let name = "$vocabulary"

    let value: JSONValue
    let context: KeywordContext
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-comments-with-comment
  struct Comment: Keyword {
    static let name = "$comment"

    let value: JSONValue
    let context: KeywordContext
  }
}
