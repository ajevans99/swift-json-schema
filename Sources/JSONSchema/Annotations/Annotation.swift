struct Annotation<Keyword: AnnotationProducingKeyword>: Sendable {
  let keyword: KeywordIdentifier
  let instanceLocation: JSONPointer
  let schemaLocation: JSONPointer
  let absoluteSchemaLocation: String?
  let value: Keyword.AnnotationValue

  init(
    keyword: KeywordIdentifier,
    instanceLocation: JSONPointer,
    schemaLocation: JSONPointer,
    absoluteSchemaLocation: String? = nil,
    value: Keyword.AnnotationValue
  ) {
    self.keyword = keyword
    self.instanceLocation = instanceLocation
    self.schemaLocation = schemaLocation
    self.absoluteSchemaLocation = absoluteSchemaLocation
    self.value = value
  }

  init(keyword: Keyword, instanceLocation: JSONPointer, value: Keyword.AnnotationValue) {
    self.keyword = type(of: keyword).name
    self.instanceLocation = instanceLocation
    self.schemaLocation = keyword.context.location
    self.absoluteSchemaLocation = keyword.context.absoluteKeywordLocation()
    self.value = value
  }
}

public protocol AnyAnnotation: Sendable {
  var keyword: KeywordIdentifier { get }
  var instanceLocation: JSONPointer { get }
  var schemaLocation: JSONPointer { get }
  var absoluteSchemaLocation: String? { get }
  var jsonValue: JSONValue { get }

  func merged(with other: AnyAnnotation) -> AnyAnnotation?
}

extension Annotation: AnyAnnotation where Keyword.AnnotationValue: AnnotationValueConvertible {
  var jsonValue: JSONValue {
    self.value.value
  }
}

extension Annotation {
  func merged(with other: AnyAnnotation) -> AnyAnnotation? {
    guard let otherAnnotation = other as? Annotation<Keyword> else {
      return nil
    }

    let mergedValue = self.value.merged(with: otherAnnotation.value)

    return Annotation<Keyword>(
      keyword: self.keyword,
      instanceLocation: self.instanceLocation,
      schemaLocation: self.schemaLocation,
      absoluteSchemaLocation: self.absoluteSchemaLocation,
      value: mergedValue
    )
  }
}
