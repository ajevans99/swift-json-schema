public enum SchemaIssue: Error, Equatable { 
  case schemaShouldBeBooleanOrObject
  case unsupportedRequiredVocabulary(String)
  case invalidVocabularyFormat
}
