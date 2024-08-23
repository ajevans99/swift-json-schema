import JSONSchema

/// Analogous to `Group` in SwiftUI, this component can be used to group other components together.
/// It can also be used to transform the output of the grouped components.
public struct JSONSchema<Components: JSONSchemaComponent, NewOutput>: JSONSchemaComponent {
  let transform: @Sendable (Components.Output) -> NewOutput

  var components: Components

  /// Creates a new schema component and transforms the validated result into a new type.
  /// - Parameters:
  ///   - transform: The transform to apply to the output.
  ///   - component: The components to group together.
  public init(
    _ transform: @Sendable @escaping (Components.Output) -> NewOutput,
    @JSONSchemaBuilder component: () -> Components
  ) {
    self.transform = transform
    self.components = component()
  }

  /// Creates a new schema component.
  /// - Parameter component: The components to group together.
  public init(@JSONSchemaBuilder component: () -> Components) where Components.Output == NewOutput {
    self.transform = { $0 }
    self.components = component()
  }

  public var definition: Schema { components.definition }

  /// The annotations for this component.
  public var annotations: AnnotationOptions {
    get { components.annotations }
    set { components.annotations = newValue }
  }

  public func validate(_ value: JSONValue) -> Validated<NewOutput, String> {
    components.validate(value).map(transform)
  }
}
