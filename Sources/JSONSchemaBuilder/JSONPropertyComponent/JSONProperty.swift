import JSONSchema

/// A JSON property component for use in ``JSONPropertySchemaBuilder``.
///
/// This component is used to represent a key-value pair in a JSON object.
/// The key is a `String` and the value is a ``JSONSchemaComponent``.
public struct JSONProperty<Value: JSONSchemaComponent>: JSONPropertyComponent {
  public let key: String
  public let isRequired = false
  public let value: Value

  public init(key: String, @JSONSchemaBuilder builder: () -> Value) {
    self.key = key
    self.value = builder()
  }

  public init(key: String, value: Value) {
    self.key = key
    self.value = value
  }

  public func validate(_ input: [String: JSONValue]) -> Validated<Value.Output?, String> {
    if let jsonValue = input[key] {
      return value.validate(jsonValue).map(Optional.some)
    }
    return .valid(nil)
  }

  public func required() -> JSONPropertyComponents.CompactMap<Self, Value.Output> {
    return self.compactMap { output in
      if let output = output {
        return output
      } else {
        return nil
      }
    }
  }
}
