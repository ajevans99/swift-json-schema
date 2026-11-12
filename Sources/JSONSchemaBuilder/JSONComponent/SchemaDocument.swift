import Foundation
import JSONSchema
import OrderedCollections

/// Controls which named schemas a document extracts.
public enum SchemaDocumentReferences: Sendable {
  /// Extract nested named types into root `$defs`, even when used only once.
  case namedTypes
  /// Extract named types into root `$defs` only when the document uses them more than once.
  ///
  /// Types used once stay inline, with use-site annotations merged into the inlined schema.
  /// Types whose schema is recursive (uses `$dynamicRef` or `$dynamicAnchor`) are always
  /// extracted when referenced, so their anchors stay unique.
  case reusedTypes
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
    case .namedTypes: context = SchemaDocumentContext(rootType: rootType, policy: references)
    case .reusedTypes: context = SchemaDocumentContext(rootType: rootType, policy: references)
    }
    let component = SchemaDocumentScope.$current.withValue(context, operation: schema)
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
    if isReference, context.isExtracted(typeID) {
      return ParsingScope.parseReference(
        component,
        value: value,
        keyword: "$ref",
        referenceSchema: schemaValue,
        documentContext: context
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
    var uses: Int
  }

  private let lock = NSRecursiveLock()
  private let rootID: ObjectIdentifier?
  private var entries: [ObjectIdentifier: Entry] = [:]
  private var recursiveComponents: [ObjectIdentifier: any JSONSchemaComponent] = [:]
  private var building: Set<ObjectIdentifier> = []
  private var error: SchemaDocumentError?
  private var frozen = false
  private var finalizedSchema: JSONValue?
  private var extractedIDs: Set<ObjectIdentifier> = []
  private var inlinedDefinitions: [String: JSONValue] = [:]
  private let policy: SchemaDocumentReferences

  init(rootType: (any Schemable.Type)?, policy: SchemaDocumentReferences) {
    rootID = rootType.map { ObjectIdentifier($0) }
    self.policy = policy
  }

  func isExtracted(_ id: ObjectIdentifier) -> Bool {
    lock.withLock { extractedIDs.contains(id) }
  }

  func record(_ error: SchemaDocumentError) {
    lock.withLock {
      if !frozen, self.error == nil { self.error = error }
    }
  }

  func component(for id: ObjectIdentifier) -> (any JSONSchemaComponent)? {
    lock.withLock { entries[id]?.component }
  }

  func resolvedSchema(_ value: JSONValue) throws(SchemaDocumentError) -> JSONValue {
    lock.lock()
    defer { lock.unlock() }
    return inlinedDefinitions.isEmpty
      ? value : try Self.inline(value, definitions: inlinedDefinitions)
  }

  func retainRecursive<Component: JSONSchemaComponent>(_ component: Component) {
    lock.withLock {
      guard !frozen,
        #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *),
        let type = Component.Output.self as? any Schemable.Type,
        component.schemaValue["$dynamicAnchor"]?.string == type.defaultAnchor
      else { return }
      let id = ObjectIdentifier(Component.Output.self)
      if recursiveComponents[id] == nil {
        recursiveComponents[id] = component
      }
    }
  }

  func recursiveComponent(for id: ObjectIdentifier) -> (any JSONSchemaComponent)? {
    lock.withLock { recursiveComponents[id] ?? entries[id]?.component }
  }

  func matchesReference(
    source: JSONValue,
    referenceSchema: SchemaValue,
    rootSchema: JSONValue
  ) -> Bool {
    lock.withLock {
      guard frozen, var sourceObject = source.object,
        var expected = referenceSchema.object,
        let reference = expected["$ref"]?.string,
        entries.values.contains(where: { $0.reference == reference })
      else { return false }
      // Only document-approved annotations may differ after type erasure. Constraints,
      // reference targets, and all other structural keywords must still match exactly.
      for key in Self.referenceAnnotations {
        sourceObject[key] = nil
        expected[key] = nil
      }
      if source == finalizedSchema, source == rootSchema {
        sourceObject["$defs"] = nil
      }
      return SchemaValue.object(sourceObject) == SchemaValue.object(expected)
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
          entry.uses += 1
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
      entries[id] = Entry(
        name: name,
        reference: uri,
        component: component,
        extracted: extract,
        uses: extract ? 1 : 0
      )
      return extract ? (reference, true) : (component.schemaValue, false)
    }
  }

  func finish(_ root: SchemaValue) throws(SchemaDocumentError) -> SchemaValue {
    lock.lock()
    defer { lock.unlock() }
    if let error { throw error }
    let candidates = entries.filter { $0.value.extracted }
    if !candidates.isEmpty, let definitions = root["$defs"], definitions.object == nil {
      throw .unsupportedKeyword("$defs must be an object")
    }
    var names: Set<String> = []
    for entry in candidates.values.sorted(by: { $0.name < $1.name }) {
      guard names.insert(entry.name).inserted,
        root["$defs"]?.object?[entry.name] == nil
      else { throw .conflictingDefinition(entry.name) }
    }
    var extractedEntries = candidates.filter { _, entry in
      switch policy {
      case .namedTypes: return true
      case .reusedTypes: return entry.uses > 1 || Self.containsDynamicKeyword(entry.component)
      }
    }
    // A definition that reaches itself through inlined definitions must stay extracted.
    var changed = true
    while changed {
      changed = false
      let inlinedByReference = Dictionary(
        uniqueKeysWithValues:
          candidates
          .filter { extractedEntries[$0.key] == nil }
          .map { ($0.value.reference, $0.value.component.schemaValue.value) }
      )
      for (id, entry) in candidates where extractedEntries[id] == nil {
        if Self.reaches(entry.reference, in: inlinedByReference) {
          extractedEntries[id] = entry
          changed = true
          break
        }
      }
    }
    let extracted = extractedEntries.values.sorted { $0.name < $1.name }
    let extractedReferences = Set(extracted.map(\.reference))
    let inlined = Dictionary(
      uniqueKeysWithValues:
        candidates
        .filter { extractedEntries[$0.key] == nil }
        .map { ($0.value.reference, $0.value.component.schemaValue.value) }
    )
    func resolved(_ value: JSONValue) throws(SchemaDocumentError) -> JSONValue {
      inlined.isEmpty ? value : try Self.inline(value, definitions: inlined)
    }
    var result = root
    if !inlined.isEmpty {
      switch try resolved(root.value) {
      case .object(let object): result = .object(object)
      case .boolean(let boolean): result = .boolean(boolean)
      default: throw .unsupportedKeyword("root must be a schema")
      }
    }
    if !extracted.isEmpty {
      guard case .object = result else {
        throw .unsupportedKeyword("boolean root with definitions")
      }
      var definitions = SchemaValue.object(result["$defs"]?.object ?? [:])
      for entry in extracted {
        guard definitions[entry.name] == nil else { throw .conflictingDefinition(entry.name) }
        definitions[entry.name] = try resolved(entry.component.schemaValue.value)
      }
      result["$defs"] = definitions.value
    }
    extractedIDs = Set(extractedEntries.keys)
    let references = extractedReferences
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
    inlinedDefinitions = inlined
    frozen = true
    finalizedSchema = result.value
    return result
  }

  func isInlined(_ uri: String) -> Bool {
    lock.withLock { inlinedDefinitions[uri] != nil }
  }

  private static func reaches(_ target: String, in definitions: [String: JSONValue]) -> Bool {
    func references(_ value: JSONValue) -> [String] {
      guard let object = value.object else { return [] }
      var found: [String] = []
      if let uri = object["$ref"]?.string { found.append(uri) }
      _ = mapSubschemas(of: object) { child in
        found += references(child)
        return child
      }
      return found
    }
    var visited: Set<String> = []
    var pending = references(definitions[target] ?? .null)
    while let uri = pending.popLast() {
      if uri == target { return true }
      guard visited.insert(uri).inserted, let definition = definitions[uri] else { continue }
      pending += references(definition)
    }
    return false
  }

  private static let referenceAnnotations: Set<String> = [
    "title", "description", "default", "examples", "deprecated",
    "readOnly", "writeOnly", "$comment",
  ]

  private static func containsDynamicKeyword(_ component: any JSONSchemaComponent) -> Bool {
    func contains(_ value: JSONValue) -> Bool {
      guard let object = value.object else { return false }
      if object["$dynamicAnchor"] != nil || object["$dynamicRef"] != nil { return true }
      var found = false
      _ = mapSubschemas(of: object) { child in
        found = found || contains(child)
        return child
      }
      return found
    }
    return contains(component.schemaValue.value)
  }

  // Replaces `$ref`s to `definitions` with the referenced schema, merging use-site annotations.
  private static func inline(
    _ value: JSONValue,
    definitions: [String: JSONValue]
  ) throws(SchemaDocumentError) -> JSONValue {
    guard let object = value.object else { return value }
    if let uri = object["$ref"]?.string, let definition = definitions[uri] {
      var siblings = object
      siblings["$ref"] = nil
      for keyword in siblings.keys where !referenceAnnotations.contains(keyword) {
        throw .unsupportedKeyword("\(keyword) beside a generated $ref")
      }
      let base = try inline(definition, definitions: definitions)
      guard var merged = base.object else {
        if siblings.isEmpty { return base }
        if base.boolean == true { return .object(siblings) }
        siblings["not"] = .object([:])
        return .object(siblings)
      }
      for (keyword, annotation) in siblings { merged[keyword] = annotation }
      return .object(merged)
    }
    var failure: SchemaDocumentError?
    let mapped = mapSubschemas(of: object) { child in
      do throws(SchemaDocumentError) {
        return try inline(child, definitions: definitions)
      } catch {
        failure = failure ?? error
        return child
      }
    }
    if let failure { throw failure }
    return .object(mapped)
  }

  // Applies `transform` to every direct subschema position of a schema object.
  private static func mapSubschemas(
    of object: OrderedDictionary<String, JSONValue>,
    _ transform: (JSONValue) -> JSONValue
  ) -> OrderedDictionary<String, JSONValue> {
    var object = object
    for (keyword, child) in object {
      switch keyword {
      case "$defs", "definitions", "properties", "patternProperties", "dependentSchemas":
        guard let children = child.object else { continue }
        object[keyword] = .object(children.mapValues(transform))
      case "allOf", "anyOf", "oneOf", "prefixItems":
        guard let children = child.array else { continue }
        object[keyword] = .array(children.map(transform))
      case "additionalProperties", "unevaluatedProperties", "items", "unevaluatedItems",
        "contains", "propertyNames", "not", "if", "then", "else", "contentSchema":
        object[keyword] = transform(child)
      default: break
      }
    }
    return object
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
      let allowed = Self.referenceAnnotations.union(["$ref"])
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
