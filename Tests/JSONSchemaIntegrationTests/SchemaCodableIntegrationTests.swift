import Foundation
import JSONSchema
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
