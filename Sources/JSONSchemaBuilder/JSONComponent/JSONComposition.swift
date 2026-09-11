import JSONSchema

public protocol JSONComposableComponent: JSONSchemaComponent {}

public protocol JSONComposableCollectionComponent: JSONComposableComponent {
  associatedtype Output

  var components: [any JSONSchemaComponent<Output>] { get }

  init(
    into output: Output.Type,
    @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnySchemaComponent<
      Output
    >]
  )
}

extension JSONComposableCollectionComponent where Output == JSONValue {
  public init(
    @JSONSchemaCollectionBuilder<JSONValue> _ builder: () -> [JSONComponents.AnySchemaComponent<
      JSONValue
    >]
  ) { self.init(into: JSONValue.self, builder) }
}

public enum JSONComposition: Sendable {
  case anyOf
  case allOf
  case oneOf
  case not

  /// A component that accepts any of the given schemas.
  public struct AnyOf<Output>: JSONComposableCollectionComponent {
    public var schemaValue = SchemaValue.object([:])

    public let components: [any JSONSchemaComponent<Output>]

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnySchemaComponent<
        Output
      >]
    ) {
      components = builder()
      schemaValue[Keywords.AnyOf.name] = .array(components.map(\.schemaValue.value))
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      ParsingScope.withRoot(self, value: value) { parseBranches(value) }
    }

    private func parseBranches(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      var allErrors: [ParseIssue] = []

      for (index, component) in components.enumerated() {
        switch ParsingScope.parseBranch(
          component,
          value: value,
          keyword: Keywords.AnyOf.name,
          index: index,
          composition: .anyOf
        ) {
        case .failure(let error): return .error(error)
        case .success(.valid(let output)): return .valid(output)
        case .success(.invalid(let errors)): allErrors.append(contentsOf: errors)
        }
      }
      return .error(
        .compositionFailure(type: .anyOf, reason: "did not match any", nestedErrors: allErrors)
      )
    }
  }

  /// A component that requires all of the schemas to be valid.
  public struct AllOf<Output>: JSONComposableCollectionComponent {
    public var schemaValue = SchemaValue.object([:])

    public let components: [any JSONSchemaComponent<Output>]

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnySchemaComponent<
        Output
      >]
    ) {
      components = builder()
      schemaValue[Keywords.AllOf.name] = .array(components.map(\.schemaValue.value))
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      ParsingScope.withRoot(self, value: value) { parseBranches(value) }
    }

    private func parseBranches(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      var combinedErrors: [ParseIssue] = []
      var validResult: Output?
      var hasFailure = false

      for (index, component) in components.enumerated() {
        switch ParsingScope.parseBranch(
          component,
          value: value,
          keyword: Keywords.AllOf.name,
          index: index,
          composition: .allOf
        ) {
        case .failure(let error): return .error(error)
        case .success(.valid(let result)): if validResult == nil { validResult = result }
        case .success(.invalid(let errors)):
          hasFailure = true
          combinedErrors.append(contentsOf: errors)
        }
      }

      guard let validResult, !hasFailure else {
        return .error(
          .compositionFailure(
            type: .allOf,
            reason: "did not match all",
            nestedErrors: combinedErrors
          )
        )
      }
      return .valid(validResult)
    }
  }

  /// A component that requires exactly one of the schemas to be valid.
  public struct OneOf<Output>: JSONComposableCollectionComponent {
    public var schemaValue = SchemaValue.object([:])

    public let components: [any JSONSchemaComponent<Output>]

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnySchemaComponent<
        Output
      >]
    ) {
      components = builder()
      schemaValue[Keywords.OneOf.name] = .array(components.map(\.schemaValue.value))
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      ParsingScope.withRoot(self, value: value) { parseBranches(value) }
    }

    private func parseBranches(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      var validResults: [Output] = []
      var combinedErrors: [ParseIssue] = []

      for (index, component) in components.enumerated() {
        switch ParsingScope.parseBranch(
          component,
          value: value,
          keyword: Keywords.OneOf.name,
          index: index,
          composition: .oneOf
        ) {
        case .failure(let error): return .error(error)
        case .success(.valid(let result)): validResults.append(result)
        case .success(.invalid(let errors)): combinedErrors.append(contentsOf: errors)
        }
      }

      if validResults.count == 1 {
        // Exactly one component validated successfully
        return .valid(validResults.first!)
      } else if validResults.isEmpty {
        // No component validated successfully
        return .error(
          .compositionFailure(type: .oneOf, reason: "no match found", nestedErrors: combinedErrors)
        )
      } else {
        // More than one component validated successfully
        return .error(
          .compositionFailure(type: .oneOf, reason: "multiple matches found", nestedErrors: [])
        )
      }
    }
  }

  /// A component that requires the value to not match the given schema.
  public struct Not<Component: JSONSchemaComponent>: JSONComposableComponent {
    public var schemaValue = SchemaValue.object([:])

    public let component: Component

    public init(@JSONSchemaBuilder _ builder: () -> Component) {
      component = builder()
      schemaValue[Keywords.Not.name] = component.schemaValue.value
    }

    public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> {
      ParsingScope.withRoot(self, value: value) {
        let evaluation: SchemaEvaluation
        switch ParsingScope.branchEvaluation(
          component,
          value: value,
          keyword: Keywords.Not.name,
          composition: .not
        ) {
        case .failure(let error): return .error(error)
        case .success(let result): evaluation = result
        }
        guard evaluation.result.isValid else { return .valid(value) }
        let parsed = ParsingScope.$current.withValue(
          ParsingScope.current?.descending(to: evaluation)
        ) { component.parse(value) }
        switch parsed {
        case .valid:
          return .error(
            .compositionFailure(type: .not, reason: "valid against not schema", nestedErrors: [])
          )
        case .invalid: return .valid(value)
        }
      }
    }
  }
}
