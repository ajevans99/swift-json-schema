/// https://json-schema.org/draft/2020-12/meta/meta-data
protocol MetadataKeyword: Keyword {}

extension Keywords {
  struct Title: MetadataKeyword {
    static let name = "title"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct Description: MetadataKeyword {
    static let name = "description"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct Default: MetadataKeyword {
    static let name = "default"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct Deprecated: MetadataKeyword {
    static let name = "deprecated"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct ReadOnly: MetadataKeyword {
    static let name = "readOnly"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct WriteOnly: MetadataKeyword {
    static let name = "writeOnly"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct Examples: MetadataKeyword {
    static let name = "examples"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }
}

extension Keywords {
  struct ContentEncoding: MetadataKeyword {
    static let name = "contentEncoding"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct ContentMediaType: MetadataKeyword {
    static let name = "contentMediaType"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct ContentSchema: MetadataKeyword {
    static let name = "contentSchema"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }
}
