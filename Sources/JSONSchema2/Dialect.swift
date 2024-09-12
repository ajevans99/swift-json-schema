public enum Dialect: Hashable, Sendable {
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

  /// The supported keywords by dialect.
  /// Order matters as some keywords require annoation results of others.
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

        Keywords.Items.self,
        Keywords.Contains.self,

        Keywords.TypeKeyword.self,

        Keywords.MultipleOf.self,
        Keywords.Maximum.self,
        Keywords.ExclusiveMaximum.self,
        Keywords.Minimum.self,
        Keywords.ExclusiveMaximum.self,

        Keywords.MaxLength.self,
        Keywords.MinLength.self,
        Keywords.Pattern.self,

        Keywords.MaxItems.self,
        Keywords.MinItems.self,
        Keywords.UniqueItems.self,
        Keywords.MaxContains.self,
        Keywords.MinContains.self,

        Keywords.MaxProperties.self,
        Keywords.MinProperties.self,
        Keywords.Required.self,
        Keywords.DependentRequired.self,
      ]
    }
  }
}
