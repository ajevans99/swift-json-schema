protocol IdentifierKeyword: Keyword {
  /// Some identity keywords need to be processed before others.
  static var dependencies: Set<KeywordIdentifier> { get }

  func processIdentifier(into context: inout Context)
}

extension IdentifierKeyword {
  static var dependencies: Set<KeywordIdentifier> { [] }

  func processIdentifier(into context: inout Context) {}
}

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-schema-keyword
  struct SchemaKeyword: IdentifierKeyword {
    static let name = "$schema"

    var schema: JSONValue
    var location: JSONPointer

    func processIdentifier(into context: inout Context) {
      context.dialect = .draft2020_12
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-schema-keyword
  struct Vocabulary: IdentifierKeyword {
    static let name = "$vocabulary"

    var schema: JSONValue
    var location: JSONPointer

  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-id-keyword
  struct Identifier: IdentifierKeyword {
    static let name = "$id"

    var schema: JSONValue
    var location: JSONPointer
  }

  struct Reference: IdentifierKeyword {
    static let name = "$ref"

    var schema: JSONValue
    var location: JSONPointer
  }

  struct Defs: IdentifierKeyword {
    static let name = "$defs"

    var schema: JSONValue
    var location: JSONPointer

    func processIdentifier(into context: inout Context) {
      guard case .object(let object) = schema else { return }
      for (key, value) in object {
        if let schema = try? Schema(rawSchema: value, location: location) {
          context.defintions[key] = schema
        }
      }
    }
  }

  struct Anchor: IdentifierKeyword {
    static let name = "$ref"

    var schema: JSONValue
    var location: JSONPointer
  }

  struct DynamicReference: IdentifierKeyword {
    static let name = "$dynamicRef"

    var schema: JSONValue
    var location: JSONPointer
  }

  struct DynamicAnchor: IdentifierKeyword {
    static let name = "$dynamicAnchor"

    var schema: JSONValue
    var location: JSONPointer

    func processIdentifier(into context: inout Context) {
      guard case let .string(string) = schema else { return }
      context.dynamicAnchors[string] = location
    }
  }

  struct Comment: IdentifierKeyword {
    static let name = "$comment"

    var schema: JSONValue
    var location: JSONPointer
  }
}
