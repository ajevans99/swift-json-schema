/// A type that represents the options for a JSON Schema type.
public protocol SchemaOptions: Codable, Equatable, Sendable {}

extension SchemaOptions {
  /// Erases the type of the schema options.
  public func eraseToAnySchemaOptions() -> AnySchemaOptions { AnySchemaOptions(self) }
}

extension SchemaOptions {
  var isEmpty: Bool {
    let mirror = Mirror(reflecting: self)
    for child in mirror.children {
      if let value = child.value as? AnyOptional, !value.isNil {
        return false
      }
    }
    return true
  }

  var nilIfEmpty: Self? { isEmpty ? nil : self }
}

protocol AnyOptional {
  var isNil: Bool { get }
}

extension Optional: AnyOptional {
  var isNil: Bool { self == nil }
}

/// A type-erased schema options type.
public struct AnySchemaOptions: Encodable, Sendable {
  private let value: any SchemaOptions

  /// Creates a type-erased schema options type.
  /// - Parameter value: The schema options to type-erase.
  public init<T: SchemaOptions>(_ value: T) { self.value = value }

  public func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }

  public init?(from decoder: Decoder, typeHint: JSONType?) throws {
    guard let typeHint, case let .single(primative) = typeHint else {
      if let dynamicOptions = try DynamicSchemaOptions(from: decoder).nilIfEmpty {
        self.value = dynamicOptions
        return
      } else {
        return nil
      }
    }

    let container = try decoder.singleValueContainer()

    switch primative {
    case .string:
      if let value = try? container.decode(StringSchemaOptions.self) {
        self = value.eraseToAnySchemaOptions()
        return
      }
    case .number:
      if let value = try? container.decode(NumberSchemaOptions.self) {
        self = value.eraseToAnySchemaOptions()
        return
      }
    case .object:
      if let value = try? container.decode(ObjectSchemaOptions.self) {
        self = value.eraseToAnySchemaOptions()
        return
      }
    case .array:
      if let value = try? container.decode(ArraySchemaOptions.self) {
        self = value.eraseToAnySchemaOptions()
        return
      }
    case .integer, .boolean, .null: return nil
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
