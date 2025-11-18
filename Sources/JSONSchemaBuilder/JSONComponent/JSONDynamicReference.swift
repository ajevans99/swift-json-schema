import JSONSchema

/// A typed wrapper around the ``$dynamicRef`` keyword that plugs directly into the
/// ``JSONSchemaBuilder`` APIs.
///
/// Use this component when you have declared a matching ``JSONSchemaComponent/dynamicAnchor(_:)``
/// elsewhere in the same schema (for example via the ``@Schemable`` macro) and you want to reuse
/// that object definition without re-encoding it. The component preserves strong typing by
/// delegating validation back through ``Schemable/schema`` for `T`.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct JSONDynamicReference<T: Schemable>: JSONSchemaComponent {
  public typealias Output = T

  public var schemaValue: SchemaValue
  private let anchor: String

  /// Creates a dynamic reference to the specified anchor name.
  ///
  /// - Parameter anchor: The fragment identifier (sans leading `#`) that points to a
  ///   ``JSONSchemaComponent/dynamicAnchor(_:)`` declaration.
  public init(anchor: String) {
    self.anchor = anchor
    self.schemaValue = .object([Keywords.DynamicReference.name: .string("#\(anchor)")])
  }

  /// Creates a dynamic reference that automatically resolves its anchor name from the
  /// referenced type using `String(reflecting:)`.
  public init() {
    self.init(anchor: T.defaultAnchor)
  }

  /// Parses the incoming value using `T`'s schema so the caller continues to work with strongly
  /// typed Swift values.
  public func parse(_ value: JSONValue) -> Parsed<T, ParseIssue> {
    T.schema.parse(value)
      .flatMap { output in
        guard let typedOutput = output as? T else {
          return .invalid([.compactMapValueNil(value: value)])
        }
        return .valid(typedOutput)
      }
  }
}
