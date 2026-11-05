import Foundation
import OrderedCollections

package struct AnnotationContainer {
  struct AnnotationKey: Hashable {
    let keywordType: ObjectIdentifier
    let keyword: KeywordIdentifier
    let instanceLocation: JSONPointer
  }

  private struct SourceKey: Hashable {
    let annotation: AnnotationKey
    let schemaLocation: JSONPointer
    let absoluteSchemaLocation: URL?
  }

  // OrderedDictionary so `allAnnotations()` returns annotations in the
  // order they were inserted — the validation traversal order — rather
  // than randomized Dictionary iteration order. Required for #149.
  private var storage: OrderedDictionary<SourceKey, AnyAnnotation> = [:]
  private var aggregates: [AnnotationKey: AnyAnnotation] = [:]

  package init() {}

  mutating func insert<K: AnnotationProducingKeyword>(
    keyword: K,
    at instanceLocation: JSONPointer,
    value: K.AnnotationValue
  ) {
    let annotation = Annotation<K>(
      keyword: keyword,
      instanceLocation: instanceLocation,
      value: value
    )
    insert(annotation)
  }

  mutating func insert<K: AnnotationProducingKeyword>(_ annotation: Annotation<K>) {
    let key = AnnotationKey(
      keywordType: ObjectIdentifier(K.self),
      keyword: annotation.keyword,
      instanceLocation: annotation.instanceLocation
    )
    insert(annotation, for: key)
  }

  mutating func insertUnknown(
    keyword: KeywordIdentifier,
    context: KeywordContext,
    at instanceLocation: JSONPointer,
    value: JSONValue
  ) {
    let annotation = UnknownAnnotation(
      keyword: keyword,
      instanceLocation: instanceLocation,
      schemaLocation: context.location,
      absoluteSchemaLocation: context.absoluteKeywordLocation(),
      jsonValue: value
    )
    insert(
      annotation,
      for: AnnotationKey(
        keywordType: ObjectIdentifier(UnknownAnnotation.self),
        keyword: keyword,
        instanceLocation: instanceLocation
      )
    )
  }

  private mutating func insert(_ annotation: AnyAnnotation, for key: AnnotationKey) {
    let source = SourceKey(
      annotation: key,
      schemaLocation: annotation.schemaLocation,
      absoluteSchemaLocation: annotation.absoluteSchemaLocation
    )
    if let existing = storage[source] {
      if existing.jsonValue != annotation.jsonValue {
        storage[source] = existing.merged(with: annotation)
      }
    } else {
      storage[source] = annotation
    }
    aggregates[key] = aggregates[key]?.merged(with: annotation) ?? annotation
  }

  private struct UnknownAnnotation: AnyAnnotation {
    let keyword: KeywordIdentifier
    let instanceLocation: JSONPointer
    let schemaLocation: JSONPointer
    let absoluteSchemaLocation: URL?
    let jsonValue: JSONValue

    func merged(with other: AnyAnnotation) -> AnyAnnotation? {
      other as? Self
    }
  }

  func annotation<K: AnnotationProducingKeyword>(
    for keyword: K.Type,
    at instanceLocation: JSONPointer
  ) -> Annotation<K>? {
    let key = AnnotationKey(
      keywordType: ObjectIdentifier(keyword),
      keyword: keyword.name,
      instanceLocation: instanceLocation
    )
    return aggregates[key] as? Annotation<K>
  }

  func allAnnotations() -> [AnyAnnotation] {
    Array(storage.values)
  }

  mutating func merge(_ other: AnnotationContainer) {
    if storage.isEmpty {
      storage = other.storage
      aggregates = other.aggregates
      return
    }
    for (key, otherAnnotation) in other.storage {
      insert(otherAnnotation, for: key.annotation)
    }
  }
}
