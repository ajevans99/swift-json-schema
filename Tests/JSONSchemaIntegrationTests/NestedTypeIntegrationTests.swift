import JSONSchemaBuilder
import Testing

// Test that @Schemable works with qualified type names (MemberType syntax)
enum Weather {
  @Schemable
  enum Condition: String, Sendable {
    case sunny
    case rainy
  }
}

@Schemable
struct Forecast: Sendable {
  let date: String
  let condition: Weather.Condition
}

struct MemberTypeTests {
  @Test func qualifiedTypeNameSupport() throws {
    // Verify that properties with qualified type names like Weather.Condition
    // are properly included in schema generation
    let json = """
      {"date":"2025-10-30","condition":"rainy"}
      """
    let result = try Forecast.schema.parse(instance: json)
    #expect(result.value != nil)
    #expect(result.value?.date == "2025-10-30")
    #expect(result.value?.condition == .rainy)
  }
}
