import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct SchemaOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "SchemaOptions": SchemaOptionsMacro.self,
  ]

  @Test func simple() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @SchemaOptions(.description("The current temperature in fahrenheit, like 70°F"))
        let temperature: Double
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .description("The current temperature in fahrenheit, like 70°F")
                }
                .required()
              }
            }
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func all() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
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

        @SchemaOptions(
          .title("Humidity"),
          .description("The current humidity percentage"),
          .default(50),
          .examples([40, 50, 60]),
          .readOnly(false),
          .writeOnly(true),
          .deprecated(false),
          .comment("This is a comment about humidity")
        )
        let humidity: Int
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double
          let humidity: Int

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .title("Temperature")
                  .description("The current temperature in fahrenheit, like 70°F")
                  .default(75.0)
                  .examples([72.0, 75.0, 78.0])
                  .readOnly(true)
                  .writeOnly(false)
                  .deprecated(true)
                  .comment("This is a comment about temperature")
                }
                .required()
                JSONProperty(key: "humidity") {
                  JSONInteger()
                  .title("Humidity")
                  .description("The current humidity percentage")
                  .default(50)
                  .examples([40, 50, 60])
                  .readOnly(false)
                  .writeOnly(true)
                  .deprecated(false)
                  .comment("This is a comment about humidity")
                }
                .required()
              }
            }
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func onStruct() {
    assertMacroExpansion(
      """
      @Schemable
      @SchemaOptions(
        .title("Weather Data"),
        .description("Contains weather-related information"),
        .deprecated(false)
      )
      struct Weather {
        let cityName: String
      }
      """,
      expandedSource: """
        struct Weather {
          let cityName: String

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "cityName") {
                  JSONString()
                }
                .required()
              }
              .title("Weather Data")
              .description("Contains weather-related information")
              .deprecated(false)
            }
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func onEnum() {
    assertMacroExpansion(
      """
      @Schemable
      @SchemaOptions(
        .title("Weather"),
        .description("The current weather conditions"),
        .deprecated(false)
      )
      enum Weather {
        case sunny
        case cloudy
        case rainy
      }
      """,
      expandedSource: """
        enum Weather {
          case sunny
          case cloudy
          case rainy

          static var schema: some JSONSchemaComponent<Weather> {
            JSONString()
              .enumValues {
                "sunny"
                "cloudy"
                "rainy"
              }
              .compactMap {
                switch $0 {
                case "sunny":
                  return Self.sunny
                case "cloudy":
                  return Self.cloudy
                case "rainy":
                  return Self.rainy
                default:
                  return nil
                }
              }
            .title("Weather")
            .description("The current weather conditions")
            .deprecated(false)
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func customSchema() {
    assertMacroExpansion(
      """
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
      """,
      expandedSource: """
        struct User {
          let id: UUID
          let createdAt: Date
          let website: URL
          let ipAddress: String

          static var schema: some JSONSchemaComponent<User> {
            JSONSchema(User.init) {
              JSONObject {
                JSONProperty(key: "id") {
                  Conversions.uuid.schema
                }
                .required()
                JSONProperty(key: "createdAt") {
                  Conversions.dateTime.schema
                }
                .required()
                JSONProperty(key: "website") {
                  Conversions.url.schema
                }
                .required()
                JSONProperty(key: "ipAddress") {
                  IPAddress.self.schema
                }
                .required()
              }
            }
          }
        }

        extension User: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
