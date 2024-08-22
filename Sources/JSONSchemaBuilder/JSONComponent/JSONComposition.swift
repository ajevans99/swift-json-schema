import JSONSchema

public protocol JSONComposableComponent: JSONSchemaComponent {
  var compositionOptions: CompositionOptions { get }
}

extension JSONComposableComponent {
  public var definition: Schema { .noType(annotations, composition: compositionOptions) }
}

protocol JSONComposableCollectionComponent: JSONComposableComponent {
  associatedtype Output

  var components: [any JSONSchemaComponent<Output>] { get }

  init(
    into output: Output.Type,
    @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
  )
}

extension JSONComposableCollectionComponent where Output == JSONValue {
  init(@JSONSchemaCollectionBuilder<JSONValue> _ builder: () -> [JSONComponents.AnyComponent<JSONValue>]) {
    self.init(into: JSONValue.self, builder)
  }
}

public enum JSONComposition {
  /// A component that accepts any of the given schemas.
  public struct AnyOf<Output>: JSONComposableCollectionComponent {
    public var annotations: AnnotationOptions = .annotations()

    let components: [any JSONSchemaComponent<Output>]
    public let compositionOptions: CompositionOptions

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
    ) {
      components = builder()
      compositionOptions = .anyOf(components.map(\.definition))
    }

    public func validate(_ value: JSONValue) -> Validated<Output, String> {
      var allErrors: [String] = []

      for component in components {
        switch component.validate(value) {
        case .valid(let output):
          return .valid(output)
        case .invalid(let errors):
          allErrors.append(contentsOf: errors)
        }
      }
      return .invalid(["No valid component matched for value: \(value)"] + allErrors)
    }
  }

  /// A component that requires all of the schemas to be valid.
  public struct AllOf<Output>: JSONComposableCollectionComponent {
    public var annotations: AnnotationOptions = .annotations()

    let components: [any JSONSchemaComponent<Output>]
    public let compositionOptions: CompositionOptions

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
    ) {
      components = builder()
      compositionOptions = .allOf(components.map(\.definition))
    }

    public func validate(_ value: JSONValue) -> Validated<Output, String> {
      guard !components.isEmpty else {
        return .error("AllOf validation requires at least one schema component")
      }

      var combinedErrors: [String] = []
      var validResult: Output?

      for component in components {
        switch component.validate(value) {
        case .valid(let result):
          if validResult == nil {
            validResult = result
          }
        case .invalid(let errors):
          combinedErrors.append(contentsOf: errors)
        }
      }

      if let validResult = validResult, combinedErrors.isEmpty {
        return .valid(validResult)
      } else {
        return .invalid(["Failed AllOf validation"] + combinedErrors)
      }
    }
  }

  /// A component that requires exactly one of the schemas to be valid.
  public struct OneOf<Output>: JSONComposableCollectionComponent {
    public var annotations: AnnotationOptions = .annotations()

    let components: [any JSONSchemaComponent<Output>]
    public let compositionOptions: CompositionOptions

    public init(
      into output: Output.Type,
      @JSONSchemaCollectionBuilder<Output> _ builder: () -> [JSONComponents.AnyComponent<Output>]
    ) {
      components = builder()
      compositionOptions = .oneOf(components.map(\.definition))
    }

    public func validate(_ value: JSONValue) -> Validated<Output, String> {
      var validResults: [Output] = []
      var combinedErrors: [String] = []

      for component in components {
        switch component.validate(value) {
        case .valid(let result):
          validResults.append(result)
        case .invalid(let errors):
          combinedErrors.append(contentsOf: errors)
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
        return .invalid(["Failed OneOf validation. Multiple components matched, but exactly one is required."])
      }
    }
  }

  /// A component that requires the value to not match the given schema.
  public struct Not<Component: JSONSchemaComponent>: JSONComposableComponent {
    public var annotations: AnnotationOptions = .annotations()

    let component: Component
    public let compositionOptions: CompositionOptions

    public init(@JSONSchemaBuilder _ builder: () -> Component) {
      component = builder()
      compositionOptions = .not(component.definition)
    }

    public func validate(_ value: JSONValue) -> Validated<JSONValue, String> {
      switch component.validate(value) {
      case .valid: return .error("\(value) is valid against the not schema.")
      case .invalid: return .valid(value)
      }
    }
  }
}
