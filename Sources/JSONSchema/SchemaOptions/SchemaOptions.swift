/// A type that represents the options for a JSON Schema type.
public protocol SchemaOptions: Codable, Equatable, Sendable {}

extension SchemaOptions {
  /// Erases the type of the schema options.
  public func eraseToAnySchemaOptions() -> AnySchemaOptions { AnySchemaOptions(self) }
}

/// A type-erased schema options type.
public struct AnySchemaOptions: Encodable, Sendable {
  private let value: any SchemaOptions

  /// Creates a type-erased schema options type.
  /// - Parameter value: The schema options to type-erase.
  public init<T: SchemaOptions>(_ value: T) { self.value = value }

  public func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }

  public init?(from decoder: Decoder, typeHint: JSONType) throws {
    let container = try decoder.singleValueContainer()

    func options(for primative: JSONPrimative) -> (any SchemaOptions)? {
      switch primative {
      case .string:
        if let value = try? container.decode(StringSchemaOptions.self) {
          return value
        }
      case .number:
        if let value = try? container.decode(NumberSchemaOptions.self) {
          return value
        }
      case .object:
        if let value = try? container.decode(ObjectSchemaOptions.self) {
          return value
        }
      case .array:
        if let value = try? container.decode(ArraySchemaOptions.self) {
          return value
        }
      case .integer, .boolean, .null: break
      }

      return nil
    }

    switch typeHint {
    case .single(let primative):
      if let options = options(for: primative) {
        self.value = options
        return
      }
    case .array(let primatives):
      for primative in primatives {
        if let options = options(for: primative) {
          self.value = options
          return
        }
      }
    }

    return nil
  }

  /// Attempts to cast the schema options to a specific type.
  /// - Returns: The schema options as the specified type, or `nil` if the cast fails.
  public func asType<T: SchemaOptions>() -> T? { asType(T.self) }

  /// Attempts to cast the schema options to a specific type.
  /// - Parameter type: The type to cast the schema options to.
  /// - Returns: The schema options as the specified type, or `nil` if the cast fails.
  public func asType<T: SchemaOptions>(_ type: T.Type) -> T? { value as? T }
}
