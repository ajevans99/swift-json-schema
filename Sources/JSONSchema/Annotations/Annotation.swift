import Foundation

struct Annotation<Keyword: AnnotationProducingKeyword>: Sendable {
  let keyword: KeywordIdentifier
  let instanceLocation: JSONPointer
  let schemaLocation: JSONPointer
  let absoluteSchemaLocation: URL?
  let value: Keyword.AnnotationValue

  init(
    keyword: KeywordIdentifier,
    instanceLocation: JSONPointer,
    schemaLocation: JSONPointer,
    absoluteSchemaLocation: URL? = nil,
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
  var absoluteSchemaLocation: URL? { get }
  var jsonValue: JSONValue { get }

  func merged(with other: AnyAnnotation) -> AnyAnnotation?
}

extension Annotation: AnyAnnotation where Keyword.AnnotationValue: AnnotationValueConvertible {
  var jsonValue: JSONValue {
    self.value.value
  }
}

extension Annotation {
  /// Merges two annotations that share an instance location and keyword type.
  ///
  /// - Important: When the two annotations originate from different schema
  ///   locations (for example, sibling branches of an `allOf` that both
  ///   produce `properties` annotations), the merged annotation keeps
  ///   `self`'s `schemaLocation` and `absoluteSchemaLocation`. The JSON
  ///   Schema spec encourages preserving every source for downstream
  ///   consumers; a future change should switch the annotation container
  ///   to a multi-value keyed structure so each source survives the merge.
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
