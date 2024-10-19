protocol ReservedKeyword: Keyword {}

extension Keywords {
  struct Defintions: ReservedKeyword {
    static let name = "defintions"

    let value: JSONValue
    let context: KeywordContext
  }

  struct Dependencies: ReservedKeyword {
    static let name = "dependencies"

    let value: JSONValue
    let context: KeywordContext
  }

  struct RecursiveAnchor: ReservedKeyword {
    static let name = "$recursiveAnchor"

    let value: JSONValue
    let context: KeywordContext
  }

  struct RecursiveReference: ReservedKeyword {
    static let name = "$recursiveRef"

    let value: JSONValue
    let context: KeywordContext
  }
}
