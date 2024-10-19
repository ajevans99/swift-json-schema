package protocol AnnotationProducingKeyword: Keyword {
  /// The type of the annoation value that can be produced as a result of this applying this keyword during validaiton.
  associatedtype AnnotationValue: AnnotationValueConvertible
}

package protocol AnnotationValueConvertible: Sendable, Equatable {
  var value: JSONValue { get }

  func merged(with other: Self) -> Self
}

extension JSONValue: AnnotationValueConvertible {
  package var value: JSONValue {
    self
  }

  package func merged(with other: JSONValue) -> JSONValue {
    switch (self, other) {
    case (.array(let lhs), .array(let rhs)):
      .array(lhs + rhs)
    case (.object(let lhs), .object(let rhs)):
      .object(lhs.merging(rhs, uniquingKeysWith: { $1 }))
    default:
      other
    }
  }
}
