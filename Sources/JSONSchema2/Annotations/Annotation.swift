struct Annotation<Value: Sendable>: Sendable {
  let keyword: KeywordIdentifier
  let instanceLocation: JSONPointer
  let schemaLocation: JSONPointer
  let absoluteSchemaLocation: JSONPointer?
  let value: Value
}
