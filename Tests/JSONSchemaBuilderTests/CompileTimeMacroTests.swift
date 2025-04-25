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
  @NumberOptions(.multipleOf(0.5))
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
  },
  .patternProperties {
    JSONProperty(key: "^[A-Za-z_][A-Za-z0-9_]*$") {
      JSONBoolean()
    }
  }
)
public struct Weather2 {
  let temperature: Double
}

@Schemable
@ObjectOptions(
  .minProperties(2),
  .maxProperties(5),
  .propertyNames {
    JSONString()
      .pattern("^[A-Za-z_][A-Za-z0-9_]*$")
  },
  .unevaluatedProperties {
    JSONString()
  }
)
struct Weather3 {
  let cityName: String
}

@Schemable
struct Weather4 {
  @SchemaOptions(
    .title("Temperature"),
    .description("The current temperature in fahrenheit, like 70°F"),
    .default(75.0),
    .examples([72.0, 75.0, 78.0]),
    .readOnly(true),
    .writeOnly(false),
    .deprecated(true),
    .comment("This is a comment about temperature")
  )
  let temperature: Double
}
