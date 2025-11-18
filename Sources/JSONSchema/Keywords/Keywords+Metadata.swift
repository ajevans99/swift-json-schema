/// https://json-schema.org/draft/2020-12/meta/meta-data
protocol MetadataKeyword: Keyword, AnnotationProducingKeyword where AnnotationValue == JSONValue {}

extension MetadataKeyword {
  package static var vocabulary: String {
    "https://json-schema.org/draft/2020-12/vocab/meta-data"
  }

  package func recordAnnotation(
    at instanceLocation: JSONPointer,
    using annotations: inout AnnotationContainer
  ) {
    annotations.insert(keyword: self, at: instanceLocation, value: value)
  }
}

protocol ContentKeyword: Keyword {}

extension ContentKeyword {
  package static var vocabulary: String {
    "https://json-schema.org/draft/2020-12/vocab/content"
  }
}

extension Keywords {
  package struct Title: MetadataKeyword {
    package static let name = "title"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct Description: MetadataKeyword {
    package static let name = "description"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct Default: MetadataKeyword {
    package static let name = "default"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct Deprecated: MetadataKeyword {
    package static let name = "deprecated"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct ReadOnly: MetadataKeyword {
    package static let name = "readOnly"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct WriteOnly: MetadataKeyword {
    package static let name = "writeOnly"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct Examples: MetadataKeyword {
    package static let name = "examples"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }
}

extension Keywords {
  package struct ContentEncoding: ContentKeyword {
    package static let name = "contentEncoding"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct ContentMediaType: ContentKeyword {
    package static let name = "contentMediaType"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct ContentSchema: ContentKeyword {
    package static let name = "contentSchema"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }
}
