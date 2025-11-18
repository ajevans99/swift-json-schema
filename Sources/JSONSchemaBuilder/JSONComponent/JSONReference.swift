import JSONSchema

/// A typed wrapper around the ``$ref`` keyword that keeps validation strongly typed.
///
/// Use this component when reusing an existing schema (local or remote) and you know the target
/// type conforms to ``Schemable``. The component emits `$ref` in the JSON Schema document while
/// delegating parsing back through `T.schema` so downstream code continues to work with the
/// expected Swift value.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct JSONReference<T: Schemable>: JSONSchemaComponent {
  public typealias Output = T

  public var schemaValue: SchemaValue
  private let uri: String

  /// Creates a reference to the provided URI (absolute or relative).
  ///
  /// - Parameter uri: The URI that will be stored in the generated `$ref` keyword.
  public init(uri: String) {
    self.uri = uri
    self.schemaValue = .object([Keywords.Reference.name: .string(uri)])
  }

  /// Parses the referenced schema by delegating back to `T.schema`.
  public func parse(_ value: JSONValue) -> Parsed<T, ParseIssue> {
    T.schema.parse(value).flatMap { output in
      guard let typedOutput = output as? T else {
        return .invalid([.compactMapValueNil(value: value)])
      }
      return .valid(typedOutput)
    }
  }
}
