import JSONSchema

enum ParsingScope {
  struct State: Sendable {
    let evaluation: SchemaEvaluation?
    let context: Context
    let allowsIndependentEvaluation: Bool

    init(evaluation: SchemaEvaluation, context: Context) {
      self.evaluation = evaluation
      self.context = context
      self.allowsIndependentEvaluation = !Self.hasCustomVocabulary(evaluation.schema)
    }

    private init(evaluation: SchemaEvaluation?, parent: State) {
      self.evaluation = evaluation
      self.context = parent.context
      self.allowsIndependentEvaluation =
        parent.allowsIndependentEvaluation
        && !Self.hasCustomVocabulary(evaluation?.schema ?? .boolean(true))
    }

    func descending(to evaluation: SchemaEvaluation?) -> State {
      State(evaluation: evaluation, parent: self)
    }

    private static func hasCustomVocabulary(_ value: JSONValue) -> Bool {
      switch value {
      case .object(let object):
        if object["$vocabulary"] != nil { return true }
        if let dialect = object["$schema"],
          dialect != .string("https://json-schema.org/draft/2020-12/schema")
        {
          return true
        }
        return object.values.contains(where: hasCustomVocabulary)
      case .array(let values): return values.contains(where: hasCustomVocabulary)
      default: return false
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
    switch value {
    case .object(let object):
      return object["$ref"] != nil || object["$dynamicRef"] != nil
        || object.values.contains(where: containsReference)
    case .array(let values): return values.contains(where: containsReference)
    default: return false
    }
  }

  static func parseReference<Component: JSONSchemaComponent>(
    _ component: Component,
    value: JSONValue,
    keyword: String
  ) -> Parsed<Component.Output, ParseIssue> {
    guard let current else { return component.parse(value) }
    let target = current.evaluation?.children
      .first {
        $0.reference == keyword && $0.instance == value
      }
    return $current.withValue(current.descending(to: target)) { component.parse(value) }
  }
}
