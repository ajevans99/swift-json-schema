import JSONSchema

enum ParsingScope {
  struct State: Sendable {
    let evaluation: SchemaEvaluation?
    let context: Context
    let rootSchema: JSONValue
    let allowsIndependentEvaluation: Bool

    init(evaluation: SchemaEvaluation, context: Context, rootSchema: JSONValue? = nil) {
      self.evaluation = evaluation
      self.context = context
      self.rootSchema = rootSchema ?? evaluation.schema
      self.allowsIndependentEvaluation = !Self.hasCustomVocabulary(evaluation.schema)
    }

    private init(evaluation: SchemaEvaluation?, parent: State, throughReference: Bool) {
      self.evaluation = evaluation
      self.context = parent.context
      self.rootSchema = parent.rootSchema
      self.allowsIndependentEvaluation =
        parent.allowsIndependentEvaluation
        && (!throughReference || evaluation != nil)
        && !Self.hasCustomVocabulary(evaluation?.schema ?? .boolean(true))
    }

    func descending(
      to evaluation: SchemaEvaluation?,
      throughReference: Bool = false
    ) -> State {
      State(evaluation: evaluation, parent: self, throughReference: throughReference)
    }

    static func hasCustomVocabulary(_ value: JSONValue) -> Bool {
      containsScopeKeyword(value) { keyword, value in
        keyword == "$vocabulary"
          || (keyword == "$schema" && value != .string(Dialect.draft2020_12.rawValue))
      }
    }
  }

  @TaskLocal static var current: State?

  struct PropertyLocation: Sendable {
    let keyword: String
    let instanceKey: String
  }

  @TaskLocal static var propertyLocation: PropertyLocation?

  static func withRoot<Component: JSONSchemaComponent, Result>(
    _ component: Component,
    value: JSONValue,
    operation: () -> Result
  ) -> Result {
    guard current == nil else { return operation() }
    let context = Context(dialect: .draft2020_12)
    return $current.withValue(
      State(evaluation: component.definition(context: context).evaluate(value), context: context),
      operation: operation
    )
  }

  static func parse<Component: JSONSchemaComponent>(
    _ component: Component,
    value: JSONValue,
    schemaTokens: [String],
    instanceTokens: [String] = []
  ) -> Parsed<Component.Output, ParseIssue> {
    guard let current else { return component.parse(value) }
    let child = current.evaluation?
      .child(
        schemaTokens: schemaTokens,
        instanceTokens: instanceTokens,
        instance: value
      )
    return $current.withValue(current.descending(to: child)) {
      $propertyLocation.withValue(nil) { component.parse(value) }
    }
  }

  static func parseBranch<Component: JSONSchemaComponent>(
    _ component: Component,
    value: JSONValue,
    keyword: String,
    index: Int? = nil,
    composition: JSONComposition
  ) -> Result<Parsed<Component.Output, ParseIssue>, ParseIssue> {
    switch branchEvaluation(
      component,
      value: value,
      keyword: keyword,
      index: index,
      composition: composition
    ) {
    case .failure(let error): return .failure(error)
    case .success(let evaluation):
      guard evaluation.result.isValid else {
        return .success(.error(.runtimeValidationIssue(evaluation.result)))
      }
      return .success(
        $current.withValue(current?.descending(to: evaluation)) { component.parse(value) }
      )
    }
  }

  static func branchEvaluation<Component: JSONSchemaComponent>(
    _ component: Component,
    value: JSONValue,
    keyword: String,
    index: Int? = nil,
    composition: JSONComposition
  ) -> Result<SchemaEvaluation, ParseIssue> {
    let tokens = [keyword] + (index.map { [String($0)] } ?? [])
    if let evaluation = current?.evaluation?
      .child(
        schemaTokens: tokens,
        instance: value,
        schema: component.schemaValue.value
      )
    {
      return .success(evaluation)
    }
    // Type-erased projections and flatMap can parse a different schema shape.
    // Only context-independent schemas may be evaluated outside their recorded scope.
    if let current, current.allowsIndependentEvaluation,
      !State.hasCustomVocabulary(component.schemaValue.value),
      !containsReference(component.schemaValue.value)
    {
      return .success(
        component.definition(context: current.context.independentContext()).evaluate(value)
      )
    }
    return .failure(
      .compositionFailure(
        type: composition,
        reason:
          "branch validation is unavailable in the enclosing schema; referenced or custom-vocabulary projections require matching schema structure",
        nestedErrors: []
      )
    )
  }

  private static func containsReference(_ value: JSONValue) -> Bool {
    containsScopeKeyword(value) { keyword, _ in
      keyword == "$ref" || keyword == "$dynamicRef"
    }
  }

  private static func containsScopeKeyword(
    _ value: JSONValue,
    matching predicate: (String, JSONValue) -> Bool
  ) -> Bool {
    switch value {
    case .object(let object):
      if object.contains(where: { predicate($0.key, $0.value) }) { return true }
      return object.contains { keyword, value in
        switch keyword {
        case "$recursiveRef", "$recursiveAnchor":
          return false
        case "$defs", "definitions", "properties", "patternProperties", "dependentSchemas",
          "dependencies":
          // Map entry names are not keywords, even when named $recursiveRef or $recursiveAnchor.
          if let entries = value.object {
            return entries.values.contains { containsScopeKeyword($0, matching: predicate) }
          }
        default: break
        }
        return containsScopeKeyword(value, matching: predicate)
      }
    case .array(let values):
      return values.contains { containsScopeKeyword($0, matching: predicate) }
    default: return false
    }
  }

  static func parseReference<Component: JSONSchemaComponent>(
    _ component: Component,
    value: JSONValue,
    keyword: String,
    referenceSchema: SchemaValue
  ) -> Parsed<Component.Output, ParseIssue> {
    guard let current else { return component.parse(value) }
    let target: SchemaEvaluation?
    if let source = current.evaluation, source.schema == referenceSchema.value {
      target = source.children.first { $0.reference == keyword && $0.instance == value }
    } else {
      target = nil
    }
    // An unmatched reference cannot lend a detached context to nested compositions.
    return $current.withValue(current.descending(to: target, throughReference: true)) {
      component.parse(value)
    }
  }
}
