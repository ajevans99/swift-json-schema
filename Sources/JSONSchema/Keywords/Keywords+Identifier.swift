import Foundation

protocol CoreKeyword: Keyword {}

extension CoreKeyword {
  package static var vocabulary: String {
    "https://json-schema.org/draft/2020-12/vocab/core"
  }
}

protocol IdentifierKeyword: CoreKeyword {
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

      let documentURL = context.uri.withoutFragment ?? context.uri
      context.context.registerIdentifier(
        newURL.absoluteURL,
        location: .init(
          document: documentURL,
          pointer: context.location.dropLast()
        )
      )

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
      context.context.registerAnchor(newURL, at: location)
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
      context.context.registerAnchor(newURL, at: location)
      context.context.registerDynamicAnchor(anchorName, at: location, baseURI: context.uri)
    }
  }
}
