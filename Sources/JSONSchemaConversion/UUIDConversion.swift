import Foundation
import JSONSchema
import JSONSchemaBuilder

public struct UUIDConversion: Schemable {
  public static var schema: some JSONSchemaComponent<UUID> {
    JSONString()
      .format("uuid")
      .compactMap { UUID(uuidString: $0) }
  }

  public static func encode(_ value: UUID) -> JSONValue {
    .string(value.uuidString)
  }
}
