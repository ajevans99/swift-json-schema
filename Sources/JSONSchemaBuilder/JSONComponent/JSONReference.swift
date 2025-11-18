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

  /// Creates a reference using a prebuilt ``SchemaReferenceURI`` helper.
  public init(uri: SchemaReferenceURI) {
    self.init(uri: uri.rawValue)
  }

  /// References a schema stored under `#/$defs/<name>` (or legacy `#/definitions/<name>`).
  public static func definition(
    named name: String,
    location: SchemaReferenceURI.LocalLocation = .defs
  ) -> JSONReference<T> {
    JSONReference(uri: SchemaReferenceURI.definition(named: name, location: location))
  }

  /// References a schema inside the current document via a JSON Pointer.
  public static func documentPointer(_ pointer: JSONPointer) -> JSONReference<T> {
    JSONReference(uri: SchemaReferenceURI.documentPointer(pointer))
  }

  /// References a remote schema, optionally targeting a JSON Pointer inside it.
  public static func remote(
    _ uri: String,
    pointer: JSONPointer? = nil
  ) -> JSONReference<T> {
    JSONReference(uri: SchemaReferenceURI.remote(uri, pointer: pointer))
  }

  /// Parses the referenced schema by delegating back to `T.schema`.
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
