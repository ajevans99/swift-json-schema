import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

struct SchemaCodableIntegrationTests {
  @Test
  func decodeBooleanSchema() throws {
    let json = "true"
    let decoder = JSONDecoder()
    let schema = try decoder.decode(Schema.self, from: Data(json.utf8))

    let expected = try Schema(rawSchema: .boolean(true), context: Context(dialect: .draft2020_12))
    #expect(schema == expected)

  }

  @Test
  func decodeObjectSchema() throws {
    let json = """
      {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "age": { "type": "integer", "minimum": 0 }
        },
        "required": ["name"]
      }
      """
    let decoder = JSONDecoder()
    let schema = try decoder.decode(Schema.self, from: Data(json.utf8))

    let expected: JSONValue = [
      "type": "object",
      "properties": [
        "name": ["type": "string"],
        "age": ["type": "integer", "minimum": 0],
      ],
      "required": ["name"],
    ]
    let expectedSchema = try Schema(rawSchema: expected, context: Context(dialect: .draft2020_12))
    #expect(schema == expectedSchema)

  }
}

struct IPAddress: Schemable {
  static var schema: some JSONSchemaComponent<String> {
    JSONString()
      .format("ipv4")
  }
}

@Schemable
struct User {
  @SchemaOptions(.customSchema(Conversions.uuid))
  let id: UUID

  @SchemaOptions(.customSchema(Conversions.dateTime))
  let createdAt: Date

  @SchemaOptions(.customSchema(Conversions.url))
  let website: URL

  @SchemaOptions(.customSchema(IPAddress.self))
  let ipAddress: String
}

struct CustomSchemaIntegrationTests {
  @Test func parseValidInstance() throws {
    let json = """
      {"id":"123e4567-e89b-12d3-a456-426614174000","createdAt":"2025-06-27T12:34:56.789Z","website":"https://example.com","ipAddress":"192.168.0.1"}
      """
    let result = try User.schema.parse(instance: json)
    #expect(result.value != nil)
    #expect(result.errors == nil)
  }

  @Test func parseInvalidInstance() throws {
    let json = """
      {"id":"not-a-uuid","createdAt":"not-a-date","website":"not-a-url","ipAddress":"256.256.256.256"}
      """
    let result = try User.schema.parse(instance: json)
    #expect(result.value == nil)
    #expect(result.errors != nil)
  }
}
