protocol IdentifierKeyword: Keyword {
  /// Some identity keywords need to be processed before others.
  var dependencies: Set<KeywordIdentifier> { get }

  func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context)
}

extension IdentifierKeyword {
  var dependencies: Set<KeywordIdentifier> { [] }
}

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-schema-keyword
  struct SchemaKeyword: IdentifierKeyword {
    let name = "$schema"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      context.dialect = .draft2020_12
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-schema-keyword
  struct Vocabulary: IdentifierKeyword {
    let name = "$vocaulary"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      // no-op
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-the-id-keyword
  struct Identifier: IdentifierKeyword {
    let name = "$id"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      value
      location
      context
    }
  }

  struct Reference: IdentifierKeyword {
    let name = "$ref"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      value
      location
      context
    }
  }

  struct Defintion: IdentifierKeyword {
    let name = "$defs"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      guard case .object(let object) = value else { return }
      for (key, value) in object {
        if let schema = try? Schema(rawSchema: value, location: location) {
          context.defintions[key] = schema
        }
      }
    }
  }

  struct Anchor: IdentifierKeyword {
    let name = "$ref"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      value
      location
      context
    }
  }

  struct DynamicReference: IdentifierKeyword {
    let name = "$dynamicRef"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      value
      location
      context
    }
  }

  struct DynamicAnchor: IdentifierKeyword {
    let name = "$dynamicAnchor"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      guard case let .string(string) = value else { return }
      context.dynamicAnchors[string] = location.keywordLocation
    }
  }

  struct Comment: IdentifierKeyword {
    let name = "$comment"

    func processIdentifier(in value: JSONValue, at location: ValidationLocation, into context: inout Context) {
      value
      location
      context
    }
  }
}
