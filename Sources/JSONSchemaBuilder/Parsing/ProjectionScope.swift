import JSONSchema

extension ParsingScope {
  static func parseProjection<Component: JSONSchemaComponent>(
    _ component: Component,
    value: JSONValue,
    validationSchema: SchemaValue
  ) -> Parsed<Component.Output, ParseIssue> {
    if let context = current?.context, !context.hasStandardProjectionVocabulary {
      return .error(
        .projectionFailure(reason: "the caller overrides the standard draft 2020-12 vocabulary")
      )
    }
    let parsingSchema: JSONValue
    do {
      parsingSchema = try ProjectionScope.schema(
        parsing: component.schemaValue,
        validation: validationSchema,
        enclosing: current?.rootSchema
      )
    } catch {
      return .error(error)
    }

    let context = current?.context.independentContext() ?? Context(dialect: .draft2020_12)
    let schema: Schema
    do {
      schema = try Schema(rawSchema: parsingSchema, context: context)
    } catch {
      return .error(.projectionFailure(reason: "could not construct parsing schema: \(error)"))
    }
    let evaluation = schema.evaluate(value)
    guard let child = evaluation.child(schemaTokens: ["allOf", "0"], instance: value) else {
      return .error(.projectionFailure(reason: "parsing schema evaluation is unavailable"))
    }
    return $current.withValue(
      State(evaluation: child, context: context, rootSchema: parsingSchema)
    ) {
      $propertyLocation.withValue(nil) { component.parse(value) }
    }
  }
}

private enum ProjectionScope {
  private struct Scope {
    var references: [String] = []
    var hasIdentifiers = false
    var disabledVocabularies: Set<String> = []
    var usedOptionalVocabularies: Set<String> = []
  }

  private static let vocabularyBase = "https://json-schema.org/draft/2020-12/vocab/"

  static func schema(
    parsing: SchemaValue,
    validation: SchemaValue,
    enclosing: JSONValue?
  ) throws(ParseIssue) -> JSONValue {
    let sources = [enclosing, validation.value, parsing.value].compactMap { $0 }
    var definitions = SchemaValue.object([:])
    var scope = Scope()
    for source in sources {
      try check(source, scope: &scope)
      guard let value = source.object?["$defs"] else { continue }
      guard case .object(let entries) = value else {
        throw .projectionFailure(reason: "$defs must be an object")
      }
      for (name, definition) in entries {
        if let existing = definitions[name], existing != definition {
          throw .projectionFailure(reason: "conflicting root definition '\(name)'")
        }
        definitions[name] = definition
      }
    }

    // Keep the component's root schema unchanged so typed references can match their
    // recorded source, even when definitions are supplied by an enclosing projection.
    let root: JSONValue = [
      "$defs": definitions.value,
      "allOf": [parsing.value],
    ]
    var checkedReferences: Set<String> = []
    var index = 0
    while index < scope.references.count {
      let reference = scope.references[index]
      index += 1
      guard checkedReferences.insert(reference).inserted else { continue }
      guard let target = root.value(at: JSONPointer(from: reference)),
        target.object != nil || target.boolean != nil
      else {
        throw .projectionFailure(reason: "unresolved local schema reference '\(reference)'")
      }
      try check(target, scope: &scope)
    }
    let unavailable = scope.disabledVocabularies.intersection(scope.usedOptionalVocabularies)
    if !unavailable.isEmpty {
      throw .projectionFailure(
        reason:
          "projection uses keywords from omitted vocabularies: \(unavailable.sorted().joined(separator: ", "))"
      )
    }
    if scope.hasIdentifiers && !scope.references.isEmpty {
      throw .projectionFailure(
        reason: "$id and anchors are unsupported in reference-bearing projections"
      )
    }
    return root
  }

  private static func check(
    _ schema: JSONValue,
    scope: inout Scope
  ) throws(ParseIssue) {
    if case .boolean = schema { return }
    guard case .object(let object) = schema else {
      throw .projectionFailure(reason: "a parsing bundle subschema must be an object or boolean")
    }
    if let dialect = object["$schema"],
      dialect != .string(Dialect.draft2020_12.rawValue)
    {
      throw .projectionFailure(reason: "only the standard draft 2020-12 dialect is supported")
    }
    if let vocabulary = object["$vocabulary"] {
      let required = Set(["core", "applicator", "validation"].map { vocabularyBase + $0 })
      guard case .object(let entries) = vocabulary,
        required.isSubset(of: Set(entries.keys)),
        Set(entries.keys).isSubset(of: Dialect.draft2020_12.supportedVocabularies),
        entries.values.allSatisfy({ $0.boolean != nil })
      else {
        throw .projectionFailure(
          reason:
            "projections require standard core, applicator, and validation vocabularies without custom vocabularies"
        )
      }
      scope.disabledVocabularies.formUnion(
        Dialect.draft2020_12.supportedVocabularies.subtracting(entries.keys)
      )
    }
    for (keyword, vocabulary) in [
      ("format", "format-annotation"),
      ("unevaluatedItems", "unevaluated"), ("unevaluatedProperties", "unevaluated"),
      ("contentSchema", "content"), ("contentEncoding", "content"), ("contentMediaType", "content"),
    ] where object[keyword] != nil {
      scope.usedOptionalVocabularies.insert(vocabularyBase + vocabulary)
    }
    // Draft 2020-12 reserves $recursiveRef and $recursiveAnchor without reference semantics.
    scope.hasIdentifiers =
      scope.hasIdentifiers
      || ["$id", "$anchor", "$dynamicAnchor"].contains { object[$0] != nil }
    if object["$dynamicRef"] != nil {
      throw .projectionFailure(reason: "$dynamicRef is not supported in a static projection bundle")
    }
    if let reference = object["$ref"] {
      guard let uri = reference.string, uri.hasPrefix("#/$defs/"),
        !uri.contains("%")
      else {
        throw .projectionFailure(
          reason: "projection references must use local #/$defs/... pointers"
        )
      }
      scope.references.append(uri)
    }

    // Only schema-bearing keywords are traversed; const, enum, defaults, and examples
    // may legitimately contain data whose keys look like schema identifiers or vocabularies.
    for keyword in ["$defs", "definitions", "properties", "patternProperties", "dependentSchemas"] {
      guard let value = object[keyword] else { continue }
      guard case .object(let entries) = value else {
        throw .projectionFailure(reason: "\(keyword) must be an object")
      }
      for value in entries.values { try check(value, scope: &scope) }
    }
    for keyword in ["allOf", "anyOf", "oneOf", "prefixItems"] {
      guard let value = object[keyword] else { continue }
      guard case .array(let entries) = value else {
        throw .projectionFailure(reason: "\(keyword) must be an array")
      }
      for value in entries { try check(value, scope: &scope) }
    }
    for keyword in [
      "additionalProperties", "unevaluatedProperties", "items", "unevaluatedItems", "contains",
      "propertyNames", "not", "if", "then", "else", "contentSchema",
    ] {
      if let value = object[keyword] { try check(value, scope: &scope) }
    }
    if let value = object["dependencies"] {
      guard let dependencies = value.object else {
        throw .projectionFailure(reason: "dependencies must be an object")
      }
      for value in dependencies.values where value.array == nil {
        try check(value, scope: &scope)
      }
    }
  }
}
