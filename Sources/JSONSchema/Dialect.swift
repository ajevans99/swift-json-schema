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

  /// The vocabularies supported by this dialect.
  var supportedVocabularies: Set<String> {
    switch self {
    case .draft2020_12:
      [
        "https://json-schema.org/draft/2020-12/vocab/core",
        "https://json-schema.org/draft/2020-12/vocab/applicator",
        "https://json-schema.org/draft/2020-12/vocab/unevaluated",
        "https://json-schema.org/draft/2020-12/vocab/validation",
        "https://json-schema.org/draft/2020-12/vocab/meta-data",
        "https://json-schema.org/draft/2020-12/vocab/format-annotation",
        "https://json-schema.org/draft/2020-12/vocab/content",
      ]
    }
  }

  /// Maps keyword types to their vocabulary URIs
  private var keywordVocabularyMapping: [String: String] {
    switch self {
    case .draft2020_12:
      [
        // Core vocabulary
        "$schema": "https://json-schema.org/draft/2020-12/vocab/core",
        "$vocabulary": "https://json-schema.org/draft/2020-12/vocab/core",
        "$id": "https://json-schema.org/draft/2020-12/vocab/core",
        "$ref": "https://json-schema.org/draft/2020-12/vocab/core",
        "$defs": "https://json-schema.org/draft/2020-12/vocab/core",
        "$anchor": "https://json-schema.org/draft/2020-12/vocab/core",
        "$dynamicRef": "https://json-schema.org/draft/2020-12/vocab/core",
        "$dynamicAnchor": "https://json-schema.org/draft/2020-12/vocab/core",
        "$comment": "https://json-schema.org/draft/2020-12/vocab/core",

        // Applicator vocabulary
        "allOf": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "anyOf": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "oneOf": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "not": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "if": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "then": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "else": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "dependentSchemas": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "prefixItems": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "items": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "contains": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "properties": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "patternProperties": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "additionalProperties": "https://json-schema.org/draft/2020-12/vocab/applicator",
        "propertyNames": "https://json-schema.org/draft/2020-12/vocab/applicator",

        // Validation vocabulary
        "type": "https://json-schema.org/draft/2020-12/vocab/validation",
        "enum": "https://json-schema.org/draft/2020-12/vocab/validation",
        "const": "https://json-schema.org/draft/2020-12/vocab/validation",
        "multipleOf": "https://json-schema.org/draft/2020-12/vocab/validation",
        "maximum": "https://json-schema.org/draft/2020-12/vocab/validation",
        "exclusiveMaximum": "https://json-schema.org/draft/2020-12/vocab/validation",
        "minimum": "https://json-schema.org/draft/2020-12/vocab/validation",
        "exclusiveMinimum": "https://json-schema.org/draft/2020-12/vocab/validation",
        "maxLength": "https://json-schema.org/draft/2020-12/vocab/validation",
        "minLength": "https://json-schema.org/draft/2020-12/vocab/validation",
        "pattern": "https://json-schema.org/draft/2020-12/vocab/validation",
        "maxItems": "https://json-schema.org/draft/2020-12/vocab/validation",
        "minItems": "https://json-schema.org/draft/2020-12/vocab/validation",
        "uniqueItems": "https://json-schema.org/draft/2020-12/vocab/validation",
        "maxContains": "https://json-schema.org/draft/2020-12/vocab/validation",
        "minContains": "https://json-schema.org/draft/2020-12/vocab/validation",
        "maxProperties": "https://json-schema.org/draft/2020-12/vocab/validation",
        "minProperties": "https://json-schema.org/draft/2020-12/vocab/validation",
        "required": "https://json-schema.org/draft/2020-12/vocab/validation",
        "dependentRequired": "https://json-schema.org/draft/2020-12/vocab/validation",

        // Meta-data vocabulary
        "title": "https://json-schema.org/draft/2020-12/vocab/meta-data",
        "description": "https://json-schema.org/draft/2020-12/vocab/meta-data",
        "default": "https://json-schema.org/draft/2020-12/vocab/meta-data",
        "deprecated": "https://json-schema.org/draft/2020-12/vocab/meta-data",
        "readOnly": "https://json-schema.org/draft/2020-12/vocab/meta-data",
        "writeOnly": "https://json-schema.org/draft/2020-12/vocab/meta-data",
        "examples": "https://json-schema.org/draft/2020-12/vocab/meta-data",

        // Format-annotation vocabulary
        "format": "https://json-schema.org/draft/2020-12/vocab/format-annotation",

        // Content vocabulary
        "contentEncoding": "https://json-schema.org/draft/2020-12/vocab/content",
        "contentMediaType": "https://json-schema.org/draft/2020-12/vocab/content",
        "contentSchema": "https://json-schema.org/draft/2020-12/vocab/content",

        // Unevaluated vocabulary
        "unevaluatedItems": "https://json-schema.org/draft/2020-12/vocab/unevaluated",
        "unevaluatedProperties": "https://json-schema.org/draft/2020-12/vocab/unevaluated",
      ]
    }
  }

  /// Returns keywords filtered by active vocabularies. If no active vocabularies are specified, returns all keywords.
  func keywords(activeVocabularies: Set<String>? = nil) -> [any Keyword.Type] {
    let allKeywords = keywords

    guard let activeVocabs = activeVocabularies, !activeVocabs.isEmpty else {
      return allKeywords
    }

    return allKeywords.filter { keywordType in
      let keywordName = keywordType.name
      if let vocabularyURI = keywordVocabularyMapping[keywordName] {
        return activeVocabs.contains(vocabularyURI)
      }
      // If we can't find the vocabulary mapping, include the keyword (conservative approach)
      return true
    }
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
        Keywords.Format.self,

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
        withExtension: "json"
      )
    else {
      throw MetaSchemaError.missingResource
    }

    let metaURLs = Bundle.module.urls(
      forResourcesWithExtension: "json",
      subdirectory: nil
    )
    let metaDictionary: [String: JSONValue] =
      try metaURLs?
      .reduce(into: [:]) { result, url in
        #if os(Linux) || os(WASI)
          guard url.lastPathComponent?.hasPrefix("schema") == false else { return }
          let value = try jsonValue(from: url as URL)
          let uriString =
            "meta/\(url.lastPathComponent?.replacingOccurrences(of: ".json", with: "") ?? "")"
        #else
          guard !url.lastPathComponent.hasPrefix("schema") else { return }
          let value = try jsonValue(from: url)
          let uriString =
            "meta/\(url.lastPathComponent.replacingOccurrences(of: ".json", with: ""))"
        #endif
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
