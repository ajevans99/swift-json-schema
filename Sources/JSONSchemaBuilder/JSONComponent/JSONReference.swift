import JSONSchema

/// A schema component representing a `$ref`.
public struct JSONReference<Output>: JSONSchemaComponent {
  public var schemaValue: SchemaValue

  /// Creates a reference to another schema at the given URI or JSON Pointer.
  /// - Parameter ref: The value for the `$ref` keyword.
  public init(_ ref: String) {
    self.schemaValue = .object(["$ref": .string(ref)])
  }

  public func parse(_ value: JSONValue) -> Parsed<Output, ParseIssue> {
    fatalError("JSONReference cannot parse values. Resolve the reference first.")
  }
}
