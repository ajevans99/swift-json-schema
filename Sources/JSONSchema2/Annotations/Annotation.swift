struct Annotation<Keyword: AnnotationProducingKeyword>: Sendable {
  let keyword: Keyword
  let instanceLocation: JSONPointer
  let schemaLocation: JSONPointer
  let absoluteSchemaLocation: JSONPointer?
  let value: Keyword.AnnotationValue
}
