/// Namespace for `Keyword` definitions.
package enum Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-schema-keyword
  package struct SchemaKeyword: Keyword {
    package static let name = "$schema"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }

    func processIdentifier(into context: inout Context) { context.dialect = .draft2020_12 }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-vocabulary-keyword
  package struct Vocabulary: Keyword {
    package static let name = "$vocabulary"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
    
    /// Validates that all required vocabularies are supported
    func validateVocabularies() throws(SchemaIssue) {
      guard let vocabObject = value.object else {
        throw .invalidVocabularyFormat
      }
      
      let supportedVocabularies = context.context.dialect.supportedVocabularies
      
      for (vocabularyURI, required) in vocabObject {
        guard let isRequired = required.boolean else {
          throw .invalidVocabularyFormat
        }
        
        if isRequired && !supportedVocabularies.contains(vocabularyURI) {
          throw .unsupportedRequiredVocabulary(vocabularyURI)
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-comments-with-comment
  package struct Comment: Keyword {
    package static let name = "$comment"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }
}
