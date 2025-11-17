import JSONSchema

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension JSONValue {
  /// A schema component that accepts any JSON value and returns it unchanged.
  public static var schema: some JSONSchemaComponent<JSONValue> { JSONAnyValue() }
}
