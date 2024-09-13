protocol AnnotationProducingKeyword: Keyword {
  /// The type of the annoation value that can be produced as a result of this applying this keyword during validaiton.
  associatedtype AnnotationValue: AnnotationValueConvertible
}

protocol AnnotationValueConvertible: Sendable { var value: JSONValue { get } }

extension JSONValue: AnnotationValueConvertible { var value: JSONValue { self } }
