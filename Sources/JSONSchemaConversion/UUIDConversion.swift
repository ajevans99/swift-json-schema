import Foundation
import JSONSchemaBuilder

public struct UUIDConversion: Schemable {
  public static var schema: some JSONSchemaComponent<UUID> {
    JSONString()
      .format("uuid")
      .compactMap { UUID(uuidString: $0) }
  }
}
