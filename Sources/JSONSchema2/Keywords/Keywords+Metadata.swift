/// https://json-schema.org/draft/2020-12/meta/meta-data
protocol MetadataKeyword: Keyword {}

extension Keywords {
  struct Title: MetadataKeyword {
    static let name = "title"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct Description: MetadataKeyword {
    static let name = "description"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct Default: MetadataKeyword {
    static let name = "default"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct Deprecated: MetadataKeyword {
    static let name = "deprecated"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct ReadOnly: MetadataKeyword {
    static let name = "readOnly"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct WriteOnly: MetadataKeyword {
    static let name = "writeOnly"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct Examples: MetadataKeyword {
    static let name = "examples"

    let schema: JSONValue
    let location: JSONPointer
  }
}

extension Keywords {
  struct ContentEncoding: MetadataKeyword {
    static let name = "contentEncoding"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct ContentMediaType: MetadataKeyword {
    static let name = "contentMediaType"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct ContentSchema: MetadataKeyword {
    static let name = "contentSchema"

    let schema: JSONValue
    let location: JSONPointer
  }
}
