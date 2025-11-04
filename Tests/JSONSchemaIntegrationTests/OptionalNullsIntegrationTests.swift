import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable(optionalNulls: true)
struct TestStructWithOptionalInt: Codable {
  let required: String
  let optionalInt: Int?
  let optionalString: String?
}

@Suite(.serialized)
struct OptionalNullsIntegrationTests {
  struct TestError: Error {
    let message: String
    init(_ message: String) { self.message = message }
  }

  @Test func optionalIntWithOrNull() throws {
    // Test with null for optional Int
    let jsonWithNull = """
      {
        "required": "test",
        "optionalInt": null,
        "optionalString": null
      }
      """

    let result = try TestStructWithOptionalInt.schema.parse(instance: jsonWithNull)
    #expect(result.value != nil, "Expected successful parsing")
    guard let parsed = result.value else { throw TestError("Failed to parse") }
    #expect(parsed.required == "test")
    #expect(parsed.optionalInt == nil)
    #expect(parsed.optionalString == nil)
  }
}
