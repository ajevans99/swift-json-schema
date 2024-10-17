import Foundation

// swift-format-ignore: AlwaysUseLowerCamelCase
public enum Dialect: String, Hashable, Sendable {
  case draft2020_12 = "https://json-schema.org/draft/2020-12/schema"
  //  case draft2019_09
  //  case draft7
  //  case draft6
  //  case draft5

  init?(uri: String) {
    self.init(rawValue: uri)
  }

  /// The supported keywords by dialect.
  /// Order matters as some keywords require annoation results of others.
  /// In the future, keywords should define their own dependencies and order should be determined by a dependency graph algorithm.
  var keywords: [any Keyword.Type] {
    switch self {
    case .draft2020_12:
      [
        Keywords.SchemaKeyword.self,
        Keywords.Vocabulary.self,
        Keywords.Identifier.self,
        Keywords.Reference.self,
        Keywords.Defs.self,
        Keywords.Anchor.self,

        Keywords.DynamicReference.self,
        Keywords.DynamicAnchor.self,
        Keywords.Comment.self,

        Keywords.Title.self,
        Keywords.Description.self,
        Keywords.Default.self,
        Keywords.Deprecated.self,
        Keywords.ReadOnly.self,
        Keywords.WriteOnly.self,
        Keywords.Examples.self,

        Keywords.ContentEncoding.self,
        Keywords.ContentMediaType.self,
        Keywords.ContentSchema.self,

        Keywords.PrefixItems.self,
        Keywords.Items.self,
        Keywords.Contains.self,

        Keywords.Properties.self,
        Keywords.PatternProperties.self,
        Keywords.AdditionalProperties.self,
        Keywords.PropertyNames.self,

        Keywords.AllOf.self,
        Keywords.AnyOf.self,
        Keywords.OneOf.self,
        Keywords.Not.self,

        Keywords.If.self,
        Keywords.Then.self,
        Keywords.Else.self,
        Keywords.DependentSchemas.self,

        Keywords.TypeKeyword.self,
        Keywords.Enum.self,
        Keywords.Constant.self,

        Keywords.MultipleOf.self,
        Keywords.Maximum.self,
        Keywords.ExclusiveMaximum.self,
        Keywords.Minimum.self,
        Keywords.ExclusiveMinimum.self,

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

        Keywords.UnevaluatedItems.self,
        Keywords.UnevaluatedProperties.self,

        Keywords.Defintions.self,
        Keywords.Dependencies.self,
        Keywords.RecursiveAnchor.self,
        Keywords.RecursiveReference.self,
      ]
    }
  }

  func loadMetaSchema() throws -> Schema {
    let jsonDecoder = JSONDecoder()
    func jsonValue(from url: URL) throws -> JSONValue {
      let data = try Data(contentsOf: url)
      let value = try jsonDecoder.decode(JSONValue.self, from: data)
      return value
    }

    guard let baseURI = URL(string: "https://json-schema.org/draft/2020-12/schema") else {
      throw MetaSchemaError.invalidBaseURI
    }

    guard
      let schemaURL = Bundle.module.url(
        forResource: "schema",
        withExtension: "json",
        subdirectory: "Resources/draft2020-12"
      )
    else {
      throw MetaSchemaError.missingResource
    }

    let metaURLs = Bundle.module.urls(
      forResourcesWithExtension: "json",
      subdirectory: "Resources/draft2020-12/meta"
    )
    let metaDictionary: [String: JSONValue] =
      try metaURLs?
      .reduce(into: [:]) { result, url in
        let value = try jsonValue(from: url)
        let uriString = "meta/\(url.lastPathComponent.replacingOccurrences(of: ".json", with: ""))"
        if let key = URL(string: uriString, relativeTo: baseURI)?.absoluteString {
          result[key] = value
        }
      } ?? [:]
    return try Schema(
      rawSchema: try jsonValue(from: schemaURL),
      context: .init(dialect: self, remoteSchema: metaDictionary),
      baseURI: baseURI
    )
  }
}

enum MetaSchemaError: Error {
  case invalidBaseURI
  case missingResource
}
