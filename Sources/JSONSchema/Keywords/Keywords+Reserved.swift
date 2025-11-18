protocol ReservedKeyword: Keyword {}

extension ReservedKeyword {
  package static var vocabulary: String {
    // These are not part of any specific vocabulary in 2020-12
    // They are legacy keywords that may not have vocabulary restrictions
    ""
  }
}

extension Keywords {
  package struct Definitions: ReservedKeyword {
    package static let name = "definitions"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct Dependencies: ReservedKeyword {
    package static let name = "dependencies"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct RecursiveAnchor: ReservedKeyword {
    package static let name = "$recursiveAnchor"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }

  package struct RecursiveReference: ReservedKeyword {
    package static let name = "$recursiveRef"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }
  }
}
