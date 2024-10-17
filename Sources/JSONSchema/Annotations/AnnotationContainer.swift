package struct AnnotationContainer {
  struct AnnotationKey: Hashable {
    let keywordType: ObjectIdentifier
    let instanceLocation: JSONPointer
  }

  private var storage: [AnnotationKey: AnyAnnotation] = [:]

  package init() {}

  mutating func insert<K: AnnotationProducingKeyword>(
    keyword: K,
    at instanceLocation: JSONPointer,
    value: K.AnnotationValue
  ) {
    let annotation = Annotation<K>(
      keyword: type(of: keyword).name,
      instanceLocation: instanceLocation,
      schemaLocation: keyword.context.location,
      value: value
    )
    insert(annotation)
  }

  mutating func insert<K: AnnotationProducingKeyword>(_ annotation: Annotation<K>) {
    let key = AnnotationKey(
      keywordType: ObjectIdentifier(K.self),
      instanceLocation: annotation.instanceLocation
    )
    if let existingAnnotation = storage[key] {
      let mergedAnnotation = existingAnnotation.merged(with: annotation)
      storage[key] = mergedAnnotation
    } else {
      storage[key] = annotation
    }
  }

  func annotation<K: AnnotationProducingKeyword>(
    for keyword: K.Type,
    at instanceLocation: JSONPointer
  ) -> Annotation<K>? {
    let key = AnnotationKey(
      keywordType: ObjectIdentifier(keyword),
      instanceLocation: instanceLocation
    )
    return storage[key] as? Annotation<K>
  }

  func allAnnotations() -> [AnyAnnotation] {
    Array(storage.values)
  }

  mutating func merge(_ other: AnnotationContainer) {
    for (key, otherAnnotation) in other.storage {
      if let existingAnnotation = storage[key] {
        let mergedAnnotation = existingAnnotation.merged(with: otherAnnotation)
        storage[key] = mergedAnnotation
      } else {
        storage[key] = otherAnnotation
      }
    }
  }
}
