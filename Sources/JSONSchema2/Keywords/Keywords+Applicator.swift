protocol ApplicatorKeyword: AnnotationProducingKeyword {
  /// The behavior of some keywords is defined by the presense or annotation value produced by annother another.
  var dependencies: Set<KeywordIdentifier> { get }

  func validate(_ input: JSONValue, against schema: JSONValue, at location: ValidationLocation, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue)
}

extension Keywords {
  
}
