import JSONSchema

public protocol JSONComposableComponent: JSONSchemaComponent {}

public protocol JSONComposableCollectionComponent: JSONComposableComponent {
  associatedtype Output

  var components: [any JSONSchemaComponent<Output>] { get }

  init(
    into output: Output.Type,
    @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
  )
}

extension JSONComposableCollectionComponent where Output == JSONValue {
  init(
    @JSONSchemaCollectionBuilder<JSONValue> _ builder: () -> [JSONComponents.AnyComponent<
      JSONValue
    >]
  ) { self.init(into: JSONValue.self, builder) }
}

public enum JSONComposition {
  case anyOf
  case allOf
  case oneOf
  case not

  /// A component that accepts any of the given schemas.
  public struct AnyOf<Output>: JSONComposableCollectionComponent {
    public var schemaValue = [KeywordIdentifier: JSONValue]()

    public let components: [any JSONSchemaComponent<Output>]

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
    ) {
      components = builder()
      schemaValue[Keywords.AnyOf.name] = .array(components.map { .object($0.schemaValue) })
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      var allErrors: [ParseIssue] = []

      for component in components {
        switch component.parse(value) {
        case .valid(let output): return .valid(output)
        case .invalid(let errors): allErrors.append(contentsOf: errors)
        }
      }
      return .error(
        .compositionFailure(type: .anyOf, reason: "did not match any", nestedErrors: allErrors)
      )
    }
  }

  /// A component that requires all of the schemas to be valid.
  public struct AllOf<Output>: JSONComposableCollectionComponent {
    public var schemaValue = [KeywordIdentifier: JSONValue]()

    public let components: [any JSONSchemaComponent<Output>]

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
    ) {
      components = builder()
      schemaValue[Keywords.AllOf.name] = .array(components.map { .object($0.schemaValue) })
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      var combinedErrors: [ParseIssue] = []
      var validResult: Output?

      for component in components {
        switch component.parse(value) {
        case .valid(let result): if validResult == nil { validResult = result }
        case .invalid(let errors): combinedErrors.append(contentsOf: errors)
        }
      }

      guard let validResult, combinedErrors.isEmpty else {
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
    public var schemaValue = [KeywordIdentifier: JSONValue]()

    public let components: [any JSONSchemaComponent<Output>]

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
    ) {
      components = builder()
      schemaValue[Keywords.OneOf.name] = .array(components.map { .object($0.schemaValue) })
    }

    public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
      var validResults: [Output] = []
      var combinedErrors: [ParseIssue] = []

      for component in components {
        switch component.parse(value) {
        case .valid(let result): validResults.append(result)
        case .invalid(let errors): combinedErrors.append(contentsOf: errors)
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
    public var schemaValue = [KeywordIdentifier: JSONValue]()

    public let component: Component

    public init(@JSONSchemaBuilder _ builder: () -> Component) {
      component = builder()
      schemaValue[Keywords.Not.name] = .object(component.schemaValue)
    }

    public func parse(_ value: JSONValue) -> Parsed<JSONValue, ParseIssue> {
      switch component.parse(value) {
      case .valid:
        return .error(
          .compositionFailure(type: .not, reason: "valid against not schema", nestedErrors: [])
        )
      case .invalid: return .valid(value)
      }
    }
  }
}
