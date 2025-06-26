import Foundation
import JSONSchemaBuilder

public struct UUIDConversion: CustomSchemaConvertible {
  public typealias Output = UUID

  public var schema: any JSONSchemaComponent<UUID> {
    JSONString()
      .format("uuid")
      .compactMap { UUID(uuidString: $0) }
  }
}
