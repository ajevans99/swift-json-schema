import Foundation

protocol IdentifierKeyword: Keyword {
  func processIdentifier()
}

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-id-keyword
  package struct Identifier: IdentifierKeyword {
    package static let name = "$id"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }

    func processIdentifier() {}

    func processSubschema(baseURI: URL) -> URL {
      guard let string = value.string, let newURL = URL(string: string, relativeTo: baseURI) else {
        return baseURI
      }

      if !context.context.identifierRegistry.keys.contains(newURL.absoluteURL) {
        let documentURL = context.uri.withoutFragment ?? context.uri
        context.context.identifierRegistry[newURL.absoluteURL] = .init(
          document: documentURL,
          pointer: context.location.dropLast()
        )

        let newDocumentURL = newURL.absoluteURL.withoutFragment ?? newURL.absoluteURL
        if context.context.documentCache[newDocumentURL] == nil,
          let existingDocument = context.context.documentCache[documentURL]
        {
          context.context.documentCache[newDocumentURL] = SchemaDocument(
            url: newDocumentURL,
            rawSchema: existingDocument.rawSchema
          )
        }
      }

      return newURL.absoluteURL
    }
  }

  package struct Defs: IdentifierKeyword {
    package static let name = "$defs"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }

    func processIdentifier() {
      guard case .object(let object) = value else { return }
      for (key, value) in object {
        // It is important to process defs to update context
        let subschemaLocation = context.location.appending(.key(key))
        _ = try? Schema(
          rawSchema: value,
          location: subschemaLocation,
          context: context.context,
          baseURI: context.uri
        )
      }
    }
  }

  package struct Anchor: IdentifierKeyword {
    package static let name = "$anchor"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }

    func processIdentifier() {
      guard let anchorName = value.string else { return }
      var components = URLComponents(url: context.uri, resolvingAgainstBaseURL: true)
      components?.fragment = anchorName
      guard let newURL = components?.url else { return }
      let location = context.location.dropLast()
      if !context.context.anchors.keys.contains(newURL) {
        context.context.anchors[newURL] = location
      }
    }
  }

  package struct DynamicAnchor: IdentifierKeyword {
    package static let name = "$dynamicAnchor"

    package let value: JSONValue
    package let context: KeywordContext

    package init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
    }

    func processIdentifier() {
      guard let anchorName = value.string else { return }
      var components = URLComponents(url: context.uri, resolvingAgainstBaseURL: true)
      components?.fragment = anchorName
      guard let newURL = components?.url else { return }
      let location = context.location.dropLast()
      if !context.context.anchors.keys.contains(newURL) {
        context.context.anchors[newURL] = location
      }

      let documentURL = context.uri.withoutFragment ?? context.uri
      var anchors = context.context.documentDynamicAnchors[documentURL] ?? [:]
      if anchors[anchorName] == nil {
        anchors[anchorName] = (pointer: location, baseURI: context.uri)
        context.context.documentDynamicAnchors[documentURL] = anchors
      }
    }
  }
}
