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
        @SchemaOptions(description: "The current temperature in fahrenheit, like 70°F")
        let temperature: Double
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double

          static var schema: JSONSchemaComponent {
            JSONObject {
              JSONProperty(key: "temperature") {
                JSONNumber()
                  .description("The current temperature in fahrenheit, like 70°F")
              }
            }
            .required(["temperature"])
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
          title: "Temperature",
          description: "The current temperature in fahrenheit, like 70°F",
          default: 75.0,
          examples: [72.0, 75.0, 78.0],
          readOnly: true,
          writeOnly: false,
          deprecated: true,
          comment: "This is a comment about temperature"
        )
        let temperature: Double

        @SchemaOptions(
          title: "Humidity",
          description: "The current humidity percentage",
          default: 50,
          examples: [40, 50, 60],
          readOnly: false,
          writeOnly: true,
          deprecated: false,
          comment: "This is a comment about humidity"
        )
        let humidity: Int
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double
          let humidity: Int

          static var schema: JSONSchemaComponent {
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
            }
            .required(["temperature", "humidity"])
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
        title: "Weather Data",
        description: "Contains weather-related information",
        deprecated: false
      )
      struct Weather {
        let cityName: String
      }
      """,
      expandedSource: """
        struct Weather {
          let cityName: String

          static var schema: JSONSchemaComponent {
            JSONObject {
              JSONProperty(key: "cityName") {
                JSONString()
              }
            }
            .title("Weather Data")
            .description("Contains weather-related information")
            .deprecated(false)
            .required(["cityName"])
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
