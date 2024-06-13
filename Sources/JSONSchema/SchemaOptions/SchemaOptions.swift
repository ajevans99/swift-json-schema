public protocol SchemaOptions: Codable, Equatable {}

extension SchemaOptions {
  func eraseToAnySchemaOptions() -> AnySchemaOptions {
    AnySchemaOptions(self)
  }
}

struct AnySchemaOptions: Encodable {
  private let value: any SchemaOptions

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

  public func asType<T: SchemaOptions>() -> T? {
    asType(T.self)
  }

  public func asType<T: SchemaOptions>(_ type: T.Type) -> T? {
    value as? T
  }
}
