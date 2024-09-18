protocol ReservedKeyword: Keyword {}

extension Keywords {
  struct Defintions: ReservedKeyword {
    static let name = "defintions"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct Dependencies: ReservedKeyword {
    static let name = "dependencies"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct RecursiveAnchor: ReservedKeyword {
    static let name = "$recursiveAnchor"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }

  struct RecursiveReference: ReservedKeyword {
    static let name = "$recursiveRef"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
  }
}
