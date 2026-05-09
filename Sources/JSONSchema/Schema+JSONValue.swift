import OrderedCollections
import OrderedJSON

extension Schema {
  /// An ``OrderedJSON/JSONValue`` representation of this schema.
  ///
  /// For object schemas, keyword order matches the registration order in
  /// the active dialect (the same order used by ``encode(to:)``). Pairing
  /// this with ``OrderedJSON/JSONValue/serialized(options:)`` produces
  /// byte-stable JSON without going through `JSONEncoder` first — the
  /// `Codable` round-trip path required `.sortedKeys` to be deterministic
  /// and lost the original key ordering in the process.
  ///
  /// See issue #161 for the full motivation.
  public var jsonValue: JSONValue {
    schema.jsonValue
  }
}

extension BooleanSchema {
  package var jsonValue: JSONValue { .boolean(schemaValue) }
}

extension ObjectSchema {
  package var jsonValue: JSONValue {
    var dict = OrderedDictionary<String, JSONValue>()
    dict.reserveCapacity(keywords.count)
    for keyword in keywords {
      dict[type(of: keyword).name] = keyword.value
    }
    return .object(dict)
  }
}
