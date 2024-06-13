public protocol SchemaOptions: Codable {}

extension SchemaOptions {
  func eraseToAnySchemaOptions() -> AnySchemaOptions {
    AnySchemaOptions(self)
  }
}

struct AnySchemaOptions: Codable {
  private let value: SchemaOptions

  public init<T: SchemaOptions>(_ value: T) {
    self.value = value
  }

  public func encode(to encoder: Encoder) throws {
    try value.encode(to: encoder)
  }

  public init(from decoder: Decoder) throws {
    fatalError("Do we really need to decode?")
  }
}

