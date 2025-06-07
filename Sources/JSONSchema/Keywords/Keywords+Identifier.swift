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
      if let string = value.string, let newURL = URL(string: string, relativeTo: baseURI) {
        if !context.context.identifierRegistry.keys.contains(newURL.absoluteURL) {
          context.context.identifierRegistry[newURL.absoluteURL] = context.location.dropLast()
        }
        return newURL.absoluteURL
      }
      return baseURI
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
    }
  }
}
