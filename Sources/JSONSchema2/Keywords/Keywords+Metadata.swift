/// https://json-schema.org/draft/2020-12/meta/meta-data
protocol MetadataKeyword: Keyword {}

extension Keywords {
  struct Title: MetadataKeyword {
    static let name = "title"

    let value: JSONValue
    let context: KeywordContext
  }

  struct Description: MetadataKeyword {
    static let name = "description"

    let value: JSONValue
    let context: KeywordContext
  }

  struct Default: MetadataKeyword {
    static let name = "default"

    let value: JSONValue
    let context: KeywordContext
  }

  struct Deprecated: MetadataKeyword {
    static let name = "deprecated"

    let value: JSONValue
    let context: KeywordContext
  }

  struct ReadOnly: MetadataKeyword {
    static let name = "readOnly"

    let value: JSONValue
    let context: KeywordContext
  }

  struct WriteOnly: MetadataKeyword {
    static let name = "writeOnly"

    let value: JSONValue
    let context: KeywordContext
  }

  struct Examples: MetadataKeyword {
    static let name = "examples"

    let value: JSONValue
    let context: KeywordContext
  }
}

extension Keywords {
  struct ContentEncoding: MetadataKeyword {
    static let name = "contentEncoding"

    let value: JSONValue
    let context: KeywordContext
  }

  struct ContentMediaType: MetadataKeyword {
    static let name = "contentMediaType"

    let value: JSONValue
    let context: KeywordContext
  }

  struct ContentSchema: MetadataKeyword {
    static let name = "contentSchema"

    let value: JSONValue
    let context: KeywordContext
  }
}
