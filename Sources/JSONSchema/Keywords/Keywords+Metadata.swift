/// https://json-schema.org/draft/2020-12/meta/meta-data
protocol MetadataKeyword: Keyword {}

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
  package struct ContentEncoding: MetadataKeyword {
    package static let name = "contentEncoding"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct ContentMediaType: MetadataKeyword {
    package static let name = "contentMediaType"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct ContentSchema: MetadataKeyword {
    package static let name = "contentSchema"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }
}
