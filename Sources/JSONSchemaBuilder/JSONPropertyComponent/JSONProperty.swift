import JSONSchema

/// A JSON property component for use in ``JSONPropertySchemaBuilder``.
///
/// This component is used to represent a key-value pair in a JSON object.
/// The key is a `String` and the value is a ``JSONSchemaComponent``.
public struct JSONProperty<Value: JSONSchemaComponent>: JSONPropertyComponent {
  public let key: String
  public let isRequired = false
  public let value: Value

  /// Creates a new JSON property component with a key and a value.
  /// The value is created with a builder closure and is used the validate the key-value pair.
  /// - Parameters:
  ///   - key: The key for the property.
  ///   - builder: The builder closure to create the schema component for the value.
  public init(key: String, @JSONSchemaBuilder builder: () -> Value) {
    self.key = key
    self.value = builder()
  }

  /// Creates a new JSON property component with a key and a value.
  /// The schema component for validating the key-value pair.
  /// - Parameters:
  ///   - key: The key for the property.
  ///   - value: The schema component for validating the value.
  public init(key: String, value: Value) {
    self.key = key
    self.value = value
  }

  /// Creates a new JSON property component with a key. It accepts any value type.
  public init(key: String) where Value == JSONAnyValue {
    self.key = key
    self.value = JSONAnyValue()
  }

  public func validate(_ input: [String: JSONValue], against validator: Validator) -> Validation<Value.Output?> {
    if let jsonValue = input[key] { return value.validate(jsonValue, against: validator).map(Optional.some) }
    return .valid(nil)
  }

  /// By default, a property is not required and will validate as `.valid(nil)` if the key is not present in the input value.
  /// This method will mark the property as required and will validate as `.error` if the key is not present in the input value.
  public func required() -> JSONPropertyComponents.CompactMap<Self, Value.Output> {
    self.compactMap { $0 }  // CompactMap type will also wrap property as `isRequired = true`
  }
}
