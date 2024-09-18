struct Annotation<Keyword: AnnotationProducingKeyword>: Sendable {
  let keyword: KeywordIdentifier
  let instanceLocation: JSONPointer
  let schemaLocation: JSONPointer
  let absoluteSchemaLocation: JSONPointer?
  let value: Keyword.AnnotationValue

  init(keyword: KeywordIdentifier, instanceLocation: JSONPointer, schemaLocation: JSONPointer, absoluteSchemaLocation: JSONPointer? = nil, value: Keyword.AnnotationValue) {
    self.keyword = keyword
    self.instanceLocation = instanceLocation
    self.schemaLocation = schemaLocation
    self.absoluteSchemaLocation = absoluteSchemaLocation
    self.value = value
  }

  init(keyword: Keyword, instanceLocation: JSONPointer, value: Keyword.AnnotationValue) {
    self.keyword = type(of: keyword).name
    self.instanceLocation = instanceLocation
    self.schemaLocation = keyword.location
    self.absoluteSchemaLocation = nil
    self.value = value
  }
}

public protocol AnyAnnotation: Sendable {
  var keyword: KeywordIdentifier { get }
  var instanceLocation: JSONPointer { get }
  var schemaLocation: JSONPointer { get }
  var absoluteSchemaLocation: JSONPointer? { get }
  var jsonValue: JSONValue { get }
}

extension Annotation: AnyAnnotation where Keyword.AnnotationValue: AnnotationValueConvertible {
  var jsonValue: JSONValue {
    self.value.value
  }
}
