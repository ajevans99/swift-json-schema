/// A type that represents the options for a JSON Schema type.
public protocol SchemaOptions: Codable, Equatable {}

extension SchemaOptions {
  /// Erases the type of the schema options.
  func eraseToAnySchemaOptions() -> AnySchemaOptions {
    AnySchemaOptions(self)
  }
}

/// A type-erased schema options type.
public struct AnySchemaOptions: Encodable {
  private let value: any SchemaOptions

  /// Creates a type-erased schema options type.
  /// - Parameter value: The schema options to type-erase.
  public init<T: SchemaOptions>(_ value: T) {
    self.value = value
  }

  public func encode(to encoder: Encoder) throws {
    try value.encode(to: encoder)
  }

  public init?(from decoder: Decoder, typeHint: JSONType) throws {
    let container = try decoder.singleValueContainer()
    
    switch typeHint {
    case .string:
      if let value = try? container.decode(StringSchemaOptions.self) {
        self.value = value
        return
      }
    case .number:
      if let value = try? container.decode(NumberSchemaOptions.self) {
        self.value = value
        return
      }
    case .object:
      if let value = try? container.decode(ObjectSchemaOptions.self) {
        self.value = value
        return
      }
    case .array:
      if let value = try? container.decode(ArraySchemaOptions.self) {
        self.value = value
        return
      }
    case .integer, .boolean, .null:
      break
    }

    return nil
  }

  /// Attempts to cast the schema options to a specific type.
  /// - Returns: The schema options as the specified type, or `nil` if the cast fails.
  public func asType<T: SchemaOptions>() -> T? {
    asType(T.self)
  }

  /// Attempts to cast the schema options to a specific type.
  /// - Parameter type: The type to cast the schema options to.
  /// - Returns: The schema options as the specified type, or `nil` if the cast fails.
  public func asType<T: SchemaOptions>(_ type: T.Type) -> T? {
    value as? T
  }
}
