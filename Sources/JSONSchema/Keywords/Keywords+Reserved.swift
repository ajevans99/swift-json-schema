protocol ReservedKeyword: Keyword {}

extension Keywords {
  package struct Defintions: ReservedKeyword {
    package static let name = "defintions"

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
