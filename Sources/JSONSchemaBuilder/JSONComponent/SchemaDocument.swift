import JSONSchema
import OrderedCollections

/// An error produced while building a portable schema document.
public enum SchemaDocumentError: Error, Equatable {
  /// Multiple non-identical schemas declare the same dynamic anchor.
  case conflictingDynamicAnchor(String)

  /// A generated definition would replace a different existing definition.
  case conflictingDefinition(String)
}

extension JSONSchemaComponent {
  /// Builds a portable schema document by hoisting repeated dynamic anchors into `$defs`.
  ///
  /// Repeated recursive `Schemable` definitions are replaced by local `$ref`s while their
  /// `$dynamicRef`s continue to resolve through the single retained dynamic anchor.
  public func document() throws(SchemaDocumentError) -> SchemaValue {
    try SchemaDocument.bundle(schemaValue)
  }
}

private enum SchemaDocument {
  private static let objectSchemaKeywords = [
    "$defs", "definitions", "properties", "patternProperties", "dependentSchemas",
  ]
  private static let arraySchemaKeywords = ["allOf", "anyOf", "oneOf", "prefixItems"]
  private static let singleSchemaKeywords = [
    "additionalProperties", "unevaluatedProperties", "items", "unevaluatedItems", "contains",
    "propertyNames", "not", "if", "then", "else", "contentSchema",
  ]

  static func bundle(_ schema: SchemaValue) throws(SchemaDocumentError) -> SchemaValue {
    var anchors: [String: (schema: JSONValue, count: Int)] = [:]
    try collectAnchors(in: schema.value, anchors: &anchors)

    let repeated = anchors.filter { $0.value.count > 1 }
    guard !repeated.isEmpty else { return schema }

    let transformed = transform(schema.value, repeated: repeated)
    guard case .object(var root) = transformed else { return schema }

    var definitions = root["$defs"]?.object ?? OrderedDictionary()
    for (anchor, entry) in repeated {
      let definition = transformDefinition(entry.schema, repeated: repeated)
      if let existing = definitions[anchor], existing != definition {
        throw .conflictingDefinition(anchor)
      }
      definitions[anchor] = definition
    }
    root["$defs"] = .object(definitions)
    return .object(root)
  }

  private static func collectAnchors(
    in schema: JSONValue,
    anchors: inout [String: (schema: JSONValue, count: Int)]
  ) throws(SchemaDocumentError) {
    guard case .object(let object) = schema else { return }
    if let anchor = object["$dynamicAnchor"]?.string {
      if let existing = anchors[anchor] {
        guard existing.schema == schema else { throw .conflictingDynamicAnchor(anchor) }
        anchors[anchor] = (schema, existing.count + 1)
      } else {
        anchors[anchor] = (schema, 1)
      }
    }
    for child in childSchemas(of: object) {
      try collectAnchors(in: child, anchors: &anchors)
    }
  }

  private static func transform(
    _ schema: JSONValue,
    repeated: [String: (schema: JSONValue, count: Int)]
  ) -> JSONValue {
    guard case .object(var object) = schema else { return schema }
    if let anchor = object["$dynamicAnchor"]?.string, repeated[anchor] != nil {
      return ["$ref": .string(JSONPointer.pointerString(from: ["$defs", anchor]))]
    }
    transformChildSchemas(in: &object, repeated: repeated)
    return .object(object)
  }

  private static func transformDefinition(
    _ schema: JSONValue,
    repeated: [String: (schema: JSONValue, count: Int)]
  ) -> JSONValue {
    guard case .object(var object) = schema else { return schema }
    transformChildSchemas(in: &object, repeated: repeated)
    return .object(object)
  }

  private static func childSchemas(of object: OrderedDictionary<String, JSONValue>) -> [JSONValue] {
    var result: [JSONValue] = []
    for keyword in objectSchemaKeywords {
      if let entries = object[keyword]?.object {
        result.append(contentsOf: entries.values)
      }
    }
    for keyword in arraySchemaKeywords {
      result.append(contentsOf: object[keyword]?.array ?? [])
    }
    for keyword in singleSchemaKeywords {
      if let child = object[keyword] { result.append(child) }
    }
    if let dependencies = object["dependencies"]?.object {
      // Array-valued dependencies are property names, not subschemas.
      result.append(contentsOf: dependencies.values.filter { $0.array == nil })
    }
    return result
  }

  private static func transformChildSchemas(
    in object: inout OrderedDictionary<String, JSONValue>,
    repeated: [String: (schema: JSONValue, count: Int)]
  ) {
    for keyword in objectSchemaKeywords {
      guard var entries = object[keyword]?.object else { continue }
      for (name, child) in entries { entries[name] = transform(child, repeated: repeated) }
      object[keyword] = .object(entries)
    }
    for keyword in arraySchemaKeywords {
      guard let entries = object[keyword]?.array else { continue }
      object[keyword] = .array(entries.map { transform($0, repeated: repeated) })
    }
    for keyword in singleSchemaKeywords {
      guard let child = object[keyword] else { continue }
      object[keyword] = transform(child, repeated: repeated)
    }
    if var dependencies = object["dependencies"]?.object {
      for (name, child) in dependencies where child.array == nil {
        dependencies[name] = transform(child, repeated: repeated)
      }
      object["dependencies"] = .object(dependencies)
    }
  }
}
