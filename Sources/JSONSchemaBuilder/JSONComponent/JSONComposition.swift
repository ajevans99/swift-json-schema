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

    public func parse(_ value: JSONValue) -> Validated<Output, String> {
      var allErrors: [String] = []

      for component in components {
        switch component.parse(value) {
        case .valid(let output): return .valid(output)
        case .invalid(let errors): allErrors.append(contentsOf: errors)
        }
      }
      return .invalid(["No valid component matched for value: \(value)"] + allErrors)
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

    public func parse(_ value: JSONValue) -> Validated<Output, String> {
      guard !components.isEmpty else {
        return .error("AllOf validation requires at least one schema component")
      }

      var combinedErrors: [String] = []
      var validResult: Output?

      for component in components {
        switch component.parse(value) {
        case .valid(let result): if validResult == nil { validResult = result }
        case .invalid(let errors): combinedErrors.append(contentsOf: errors)
        }
      }

      guard let validResult = validResult, combinedErrors.isEmpty else {
        return .invalid(["Failed AllOf validation"] + combinedErrors)
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

    public func parse(_ value: JSONValue) -> Validated<Output, String> {
      var validResults: [Output] = []
      var combinedErrors: [String] = []

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
        return .invalid(["Failed OneOf validation. No valid component matched."] + combinedErrors)
      } else {
        // More than one component validated successfully
        return .invalid([
          "Failed OneOf validation. Multiple components matched, but exactly one is required."
        ])
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

    public func parse(_ value: JSONValue) -> Validated<JSONValue, String> {
      switch component.parse(value) {
      case .valid: return .error("\(value) is valid against the not schema.")
      case .invalid: return .valid(value)
      }
    }
  }
}
