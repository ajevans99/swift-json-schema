public enum Dialect: Hashable {
  case draft2020_12
//  case draft2019_09
//  case draft7
//  case draft6
//  case draft5

  init?(uri: String) {
    switch uri {
    case "https://json-schema.org/draft/2020-12/schema":
      self = .draft2020_12
    default:
      return nil
    }
  }

  var keywords: [any Keyword.Type] {
    switch self {
    case .draft2020_12:
      [
        Keywords.SchemaKeyword.self,
        Keywords.Vocabulary.self,
        Keywords.Identifier.self,
        Keywords.Reference.self,
        Keywords.Defintion.self,
        Keywords.Anchor.self,
        Keywords.DynamicReference.self,
        Keywords.DynamicAnchor.self,
        Keywords.Comment.self,
      ]
    }
  }
}
