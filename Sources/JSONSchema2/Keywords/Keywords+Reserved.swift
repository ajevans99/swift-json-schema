protocol ReservedKeyword: Keyword {}

extension Keywords {
  struct Defintions: ReservedKeyword {
    static let name = "defintions"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct Dependencies: ReservedKeyword {
    static let name = "dependencies"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct RecursiveAnchor: ReservedKeyword {
    static let name = "$recursiveAnchor"

    let schema: JSONValue
    let location: JSONPointer
  }

  struct RecursiveReference: ReservedKeyword {
    static let name = "$recursiveRef"

    let schema: JSONValue
    let location: JSONPointer
  }
}
