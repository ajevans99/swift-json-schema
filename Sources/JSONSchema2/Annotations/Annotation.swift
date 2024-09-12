struct Annotation<Keyword: AnnotationProducingKeyword>: Sendable {
  let keyword: Keyword
  let instanceLocation: JSONPointer
  let schemaLocation: JSONPointer
  let absoluteSchemaLocation: JSONPointer?
  let value: Keyword.AnnotationValue

  init(keyword: Keyword, instanceLocation: JSONPointer, value: Keyword.AnnotationValue) {
    self.keyword = keyword
    self.instanceLocation = instanceLocation
    self.schemaLocation = keyword.location
    self.absoluteSchemaLocation = nil
    self.value = value
  }
}
