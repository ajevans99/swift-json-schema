protocol AssertionKeyword: AnnotationProducingKeyword {
  func validate(_ input: JSONValue, against schema: JSONValue, at location: ValidationLocation, using annotations: inout AnnotationContainer) throws(ValidationIssue)
}

extension Keywords {
  
}
