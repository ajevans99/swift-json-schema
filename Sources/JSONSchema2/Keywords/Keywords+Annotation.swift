protocol AnnotationProducingKeyword: Keyword {
  /// The type of the annoation value that can be produced as a result of this applying this keyword during validaiton.
  associatedtype AnnotationValue: Sendable
}

protocol AnnotationKeyword: AnnotationProducingKeyword {
  func validate(_ input: JSONValue, against value: JSONValue, at location: ValidationLocation, using annotations: inout AnnotationContainer)
}

extension Keywords {
  
}
