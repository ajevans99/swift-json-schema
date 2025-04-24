import JSONSchemaBuilder

// These are here to prevent compile time regressions in generated macro expansions.
// Instead of asserting, they fail test target build.

@Schemable
enum Airline: String, CaseIterable {
  case delta
  case united
  case american
  case alaska
}

@Schemable
struct Flight: Sendable {
  let origin: String
  let destination: String?
  let airline: Airline
  @NumberOptions(multipleOf: 0.5)
  let duration: Double
}

@Schemable
@ObjectOptions(.additionalProperties { false })
struct Weather1 {
  let cityName: String
}

@Schemable
@ObjectOptions(
  .additionalProperties {
    JSONString()
      .pattern("^[a-zA-Z]+$")
  }
)
public struct Weather2 {
  let temperature: Double
}
