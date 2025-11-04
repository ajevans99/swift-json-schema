import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

@Suite struct BacktickEnumIntegrationTests {

  @Schemable
  enum Keywords {
    case `default`
    case `public`
    case normal
  }

  @Schemable
  enum KeywordsWithRawValues: String {
    case `default` = "default_value"
    case `public`
    case normal
  }

  @Test
  func backtickCasesWithoutRawValuesSchema() throws {
    let schema = Keywords.schema.definition()
    let jsonData = try JSONEncoder().encode(schema)
    let jsonValue = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

    // Should have enum values without backticks
    let enumValues = try #require(jsonValue["enum"] as? [String])
    #expect(enumValues.contains("default"))
    #expect(enumValues.contains("public"))
    #expect(enumValues.contains("normal"))

    // Should NOT contain backticks
    #expect(!enumValues.contains("`default`"))
    #expect(!enumValues.contains("`public`"))
  }

  @Test
  func backtickCasesWithRawValuesSchema() throws {
    let schema = KeywordsWithRawValues.schema.definition()
    let jsonData = try JSONEncoder().encode(schema)
    let jsonValue = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])

    // Should have enum values using raw values
    let enumValues = try #require(jsonValue["enum"] as? [String])
    #expect(enumValues.contains("default_value"))  // Custom raw value
    #expect(enumValues.contains("public"))         // Implicit raw value
    #expect(enumValues.contains("normal"))         // Implicit raw value

    // Should NOT contain backticks or case names for custom raw value
    #expect(!enumValues.contains("`default`"))
    #expect(!enumValues.contains("default"))
  }

  @Test
  func backtickCasesParsingWithoutRawValues() throws {
    // Test that parsing works correctly
    let jsonDefault = "\"default\""
    let jsonPublic = "\"public\""

    let parsedDefault = try Keywords.schema.parseAndValidate(instance: jsonDefault)
    let parsedPublic = try Keywords.schema.parseAndValidate(instance: jsonPublic)

    #expect(parsedDefault == .default)
    #expect(parsedPublic == .public)
  }

  @Test
  func backtickCasesParsingWithRawValues() throws {
    // Test that parsing works correctly with raw values
    let jsonDefault = "\"default_value\""
    let jsonPublic = "\"public\""

    let parsedDefault = try KeywordsWithRawValues.schema.parseAndValidate(instance: jsonDefault)
    let parsedPublic = try KeywordsWithRawValues.schema.parseAndValidate(instance: jsonPublic)

    #expect(parsedDefault == .default)
    #expect(parsedPublic == .public)

    // Should NOT parse case names when raw values exist
    #expect(throws: Error.self) {
      _ = try KeywordsWithRawValues.schema.parseAndValidate(instance: "\"default\"")
    }
  }
}
