import Foundation
import JSONSchema

/// Controls which named schemas a document extracts.
public enum SchemaDocumentReferences: Sendable {
  /// Extract nested named types into root `$defs`.
  case namedTypes
}

/// Controls a type's participation in document construction.
public enum SchemaDocumentBehavior: Sendable {
  case reusable
  case inline
}

/// An error encountered while constructing a self-contained schema document.
public enum SchemaDocumentError: Error, Equatable {
  case conflictingDefinition(String)
  case invalidDefinitionName(String)
  case recursiveConstruction(String)
  case unsupportedKeyword(String)
  case unsupportedReference(String)
  case conflictingDynamicAnchor(String)
  case missingDynamicAnchor(String)
  case nestedDocument
}

/// A self-contained schema and its matching typed parser.
///
/// Construct components inside the closure so named schemas can register their definitions.
/// Already-constructed components are not traversed to discover reusable children.
/// Apply modifiers inside the closure, before the document is finalized. Documents currently
/// support Draft 2020-12 without `$id` boundaries.
/// Use a document as the root, not as a nested component; compose the original schemas instead.
public struct SchemaDocument<Output>: JSONSchemaComponent {
  public var schemaValue: SchemaValue
  private let root: JSONComponents.AnySchemaComponent<Output>
  private let context: SchemaDocumentContext

  public init<Component: JSONSchemaComponent>(
    references: SchemaDocumentReferences = .namedTypes,
    @JSONSchemaBuilder _ schema: () -> Component
  ) throws(SchemaDocumentError) where Component.Output == Output {
    try self.init(
      references: references,
      rootType: Component.Output.self as? any Schemable.Type,
      schema
    )
  }

  init<Component: JSONSchemaComponent>(
    references: SchemaDocumentReferences,
    rootType: (any Schemable.Type)?,
    @JSONSchemaBuilder _ schema: () -> Component
  ) throws(SchemaDocumentError) where Component.Output == Output {
    guard SchemaDocumentScope.current == nil else { throw .nestedDocument }
    let context: SchemaDocumentContext
    switch references {
    case .namedTypes: context = SchemaDocumentContext(rootType: rootType)
    }
    let component = SchemaDocumentScope.$current.withValue(context, operation: schema)
    if let rootType {
      context.storeRoot(component, type: rootType)
    }
    self.schemaValue = try context.finish(component.schemaValue)
    self.root = component.eraseToAnySchemaComponent()
    self.context = context
  }

  public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
    SchemaDocumentScope.$current.withValue(context) {
      ParsingScope.withRoot(self, value: value) { root.parse(value) }
    }
  }
}

/// Preserves the identity of a named schema for document construction.
///
/// Outside a ``SchemaDocument`` this component passes through the supplied schema unchanged.
/// Inside one it emits a reference and registers the schema and parser once per Swift type.
/// Set `inline` to keep a particular use inline, for example before applying object modifiers.
public struct JSONReusable<Component: JSONSchemaComponent>: JSONSchemaComponent {
  public typealias Output = Component.Output

  public var schemaValue: SchemaValue
  private let component: Component?
  private let typeID: ObjectIdentifier
  private let isReference: Bool
  private let ownerID: ObjectIdentifier?

  /// Supports any type with a schema, including types that do not conform to `Schemable`.
  public init<T>(
    _ type: T.Type,
    inline: Bool = false,
    @JSONSchemaBuilder schema: () -> Component
  ) {
    typeID = ObjectIdentifier(type)
    if let context = SchemaDocumentScope.current {
      ownerID = ObjectIdentifier(context)
      let result = context.register(type, inline: inline, schema: schema)
      schemaValue = result.schema
      isReference = result.isReference
      component = nil
    } else {
      ownerID = nil
      let component = schema()
      self.component = component
      schemaValue = component.schemaValue
      isReference = false
    }
  }

  @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
  public init<T: Schemable>(_ type: T.Type, inline: Bool = false)
  where Component == T.Schema {
    self.init(type, inline: inline) { T.schema }
  }

  public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
    if let component { return component.parse(value) }
    guard let context = SchemaDocumentScope.current,
      ownerID == ObjectIdentifier(context),
      let component = context.component(for: typeID) as? Component
    else {
      return .error(
        .compositionFailure(
          type: .allOf,
          reason: "reusable schema must be parsed inside its owning SchemaDocument",
          nestedErrors: []
        )
      )
    }
    if isReference {
      return ParsingScope.parseReference(
        component,
        value: value,
        keyword: "$ref",
        referenceSchema: schemaValue
      )
    }
    return component.parse(value)
  }
}

enum SchemaDocumentScope {
  @TaskLocal static var current: SchemaDocumentContext?
}

// Mutation is lock-protected and confined to construction; parsing only reads frozen entries.
final class SchemaDocumentContext: @unchecked Sendable {
  private struct Entry {
    let name: String
    let reference: String
    let component: any JSONSchemaComponent
    var extracted: Bool
  }

  private let lock = NSRecursiveLock()
  private let rootID: ObjectIdentifier?
  private var entries: [ObjectIdentifier: Entry] = [:]
  private var building: Set<ObjectIdentifier> = []
  private var error: SchemaDocumentError?
  private var frozen = false

  init(rootType: (any Schemable.Type)?) {
    rootID = rootType.map { ObjectIdentifier($0) }
  }

  func record(_ error: SchemaDocumentError) {
    lock.withLock {
      if !frozen, self.error == nil { self.error = error }
    }
  }

  func component(for id: ObjectIdentifier) -> (any JSONSchemaComponent)? {
    lock.withLock { entries[id]?.component }
  }

  func storeRoot<Component: JSONSchemaComponent>(_ component: Component, type: any Schemable.Type) {
    lock.withLock {
      let id = ObjectIdentifier(type)
      if entries[id] == nil {
        entries[id] = Entry(name: "", reference: "#", component: component, extracted: false)
      }
      building.remove(id)
    }
  }

  func register<T, Component: JSONSchemaComponent>(
    _ type: T.Type,
    inline: Bool,
    schema: () -> Component
  ) -> (schema: SchemaValue, isReference: Bool) {
    lock.withLock {
      let id = ObjectIdentifier(type)
      let name: String
      let behavior: SchemaDocumentBehavior
      if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *),
        let schemable = type as? any Schemable.Type
      {
        name = schemable.schemaDefinitionName
        behavior = schemable.schemaDocumentBehavior
      } else {
        name = SchemaAnchorName.documentName(for: type)
        behavior = .reusable
      }
      let extract = !inline && behavior != .inline && id != rootID
      let fragment = String(SchemaReferenceURI.definition(named: name).rawValue.dropFirst())
      guard
        let escaped = fragment.addingPercentEncoding(
          withAllowedCharacters: CharacterSet.urlFragmentAllowed.subtracting(
            CharacterSet(charactersIn: "%")
          )
        )
      else {
        record(.invalidDefinitionName(name))
        return (.boolean(false), false)
      }
      let uri = id == rootID ? "#" : "#\(escaped)"
      let reference = SchemaValue.object([
        "$ref": .string(uri)
      ])

      if var entry = entries[id] {
        guard entry.component is Component else {
          record(.conflictingDefinition(name))
          return (reference, true)
        }
        if extract && !frozen {
          entry.extracted = true
          entries[id] = entry
        }
        return extract ? (reference, true) : (entry.component.schemaValue, false)
      }
      guard !frozen, !building.contains(id) else {
        record(.recursiveConstruction(name))
        return (reference, true)
      }
      building.insert(id)
      let component = schema()
      building.remove(id)
      entries[id] = Entry(name: name, reference: uri, component: component, extracted: extract)
      return extract ? (reference, true) : (component.schemaValue, false)
    }
  }

  func finish(_ root: SchemaValue) throws(SchemaDocumentError) -> SchemaValue {
    lock.lock()
    defer { lock.unlock() }
    if let error { throw error }
    var result = root
    let extracted = entries.values.filter(\.extracted).sorted { $0.name < $1.name }
    if !extracted.isEmpty {
      guard case .object = root else { throw .unsupportedKeyword("boolean root with definitions") }
      if let existing = root["$defs"], existing.object == nil {
        throw .unsupportedKeyword("$defs must be an object")
      }
      var definitions = SchemaValue.object(root["$defs"]?.object ?? [:])
      for entry in extracted {
        guard definitions[entry.name] == nil else { throw .conflictingDefinition(entry.name) }
        definitions[entry.name] = entry.component.schemaValue.value
      }
      result["$defs"] = definitions.value
    }
    let references = Set(extracted.map(\.reference))
    var anchors: Set<String> = []
    var dynamicReferences: Set<String> = []
    try inspect(
      result.value,
      references: references,
      anchors: &anchors,
      dynamicReferences: &dynamicReferences,
      isRoot: true
    )
    for anchor in dynamicReferences.sorted() where !anchors.contains(anchor) {
      throw .missingDynamicAnchor(anchor)
    }
    frozen = true
    return result
  }

  private func inspect(
    _ value: JSONValue,
    references: Set<String>,
    anchors: inout Set<String>,
    dynamicReferences: inout Set<String>,
    isRoot: Bool = false
  ) throws(SchemaDocumentError) {
    guard let object = value.object else { return }
    for keyword in [
      "$id", "$schema", "$vocabulary", "$anchor", "$recursiveRef", "$recursiveAnchor",
    ]
    where object[keyword] != nil {
      throw .unsupportedKeyword(keyword)
    }
    if let reference = object["$ref"] {
      guard let uri = reference.string, references.contains(uri) else {
        throw .unsupportedReference(reference.string ?? "$ref must be a string")
      }
      let allowed: Set<String> = [
        "$ref", "title", "description", "default", "examples", "deprecated",
        "readOnly", "writeOnly", "$comment",
      ]
      for keyword in object.keys
      where !allowed.contains(keyword) && !(isRoot && keyword == "$defs") {
        throw .unsupportedKeyword("\(keyword) beside a generated $ref")
      }
    }
    if let anchor = object["$dynamicAnchor"]?.string {
      guard anchors.insert(anchor).inserted else { throw .conflictingDynamicAnchor(anchor) }
    }
    if let reference = object["$dynamicRef"] {
      guard let uri = reference.string, uri.hasPrefix("#"), !uri.hasPrefix("#/") else {
        throw .unsupportedReference(reference.string ?? "$dynamicRef must be a string")
      }
      dynamicReferences.insert(String(uri.dropFirst()))
    }
    for (keyword, child) in object {
      switch keyword {
      case "$defs", "definitions", "properties", "patternProperties", "dependentSchemas":
        for schema in (child.object ?? [:]).values {
          try inspect(
            schema,
            references: references,
            anchors: &anchors,
            dynamicReferences: &dynamicReferences
          )
        }
      case "allOf", "anyOf", "oneOf", "prefixItems":
        for schema in child.array ?? [] {
          try inspect(
            schema,
            references: references,
            anchors: &anchors,
            dynamicReferences: &dynamicReferences
          )
        }
      case "additionalProperties", "unevaluatedProperties", "items", "unevaluatedItems",
        "contains", "propertyNames", "not", "if", "then", "else", "contentSchema":
        try inspect(
          child,
          references: references,
          anchors: &anchors,
          dynamicReferences: &dynamicReferences
        )
      default: break
      }
    }
  }
}
