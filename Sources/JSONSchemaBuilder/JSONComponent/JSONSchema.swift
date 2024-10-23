import JSONSchema

/// Analogous to `Group` in SwiftUI, this component can be used to group other components together.
/// It can also be used to transform the output of the grouped components.
public struct JSONSchema<Components: JSONSchemaComponent, NewOutput>: JSONSchemaComponent {
  public var schemaValue: [KeywordIdentifier : JSONValue] {
    get { components.schemaValue }
    set { components.schemaValue = newValue }
  }

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

  public func parse(_ value: JSONValue) -> Validated<NewOutput, String> {
    components.parse(value).map(transform)
  }
}
