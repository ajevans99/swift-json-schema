import Foundation

protocol IdentifierKeyword: Keyword {
  func processIdentifier()
}

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-id-keyword
  struct Identifier: IdentifierKeyword {
    static let name = "$id"

    let value: JSONValue
    let context: KeywordContext

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

  struct Defs: IdentifierKeyword {
    static let name = "$defs"

    let value: JSONValue
    let context: KeywordContext

    func processIdentifier() {
      guard case .object(let object) = value else { return }
      for (key, value) in object {
        // It is important to process defs to update context
        let subschemaLocation = context.location.appending(.key(key))
        _ = try? Schema(rawSchema: value, location: subschemaLocation, context: context.context, baseURI: context.uri)
      }
    }
  }

  struct Anchor: IdentifierKeyword {
    static let name = "$anchor"

    let value: JSONValue
    let context: KeywordContext

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

  struct DynamicAnchor: IdentifierKeyword {
    static let name = "$dynamicAnchor"

    let value: JSONValue
    let context: KeywordContext

    func processIdentifier() {
//      guard let anchorName = value.string else { return }
//      context.context.dynamicAnchors[anchorName] = context.location
    }
  }
}
