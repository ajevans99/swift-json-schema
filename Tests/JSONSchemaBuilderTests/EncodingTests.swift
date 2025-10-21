import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

struct EncodingTests {
  @Schemable(generateEncoding: true)
  struct Weather: Equatable {
    let temperature: Double
    let humidity: Int?
    let active: Bool
  }

  @Test func encodesPrimitivesAndOptionals() {
    let weather = Weather(temperature: 72.5, humidity: nil, active: true)
    #expect(
      weather.toJSONValue()
        == .object([
          "temperature": .number(72.5),
          "active": .boolean(true),
        ])
    )
  }

  @Schemable(generateEncoding: true)
  struct Account: Equatable {
    @SchemaOptions(.customSchema(Conversions.uuid))
    let id: UUID

    @SchemaOptions(.customSchema(Conversions.dateTime))
    let createdAt: Date

    @SchemaOptions(.customSchema(Conversions.url))
    let homepage: URL
  }

  @Test func encodesCustomSchemas() {
    let date = Date(timeIntervalSince1970: 1_720_000_000)
    let account = Account(
      id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
      createdAt: date,
      homepage: URL(string: "https://swift.org")!
    )

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    #expect(
      account.toJSONValue()
        == .object([
          "id": .string("123E4567-E89B-12D3-A456-426614174000"),
          "createdAt": .string(isoFormatter.string(from: date)),
          "homepage": .string("https://swift.org"),
        ])
    )
  }
}
