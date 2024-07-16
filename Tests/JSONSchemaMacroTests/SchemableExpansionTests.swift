import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct SchemableExpansionTests {
  let testMacros: [String: Macro.Type] = ["Schemable": SchemableMacro.self]

  @Test func basicTypes() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperature: Double
        let location: String
        let isRaining: Bool
        let windSpeed: Int
        let precipitationAmount: Double?
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double
          let location: String
          let isRaining: Bool
          let windSpeed: Int
          let precipitationAmount: Double?

          static var schema: JSONSchemaComponent {
            JSONObject {
              JSONProperty(key: "temperature") {
                JSONNumber()
              }
              JSONProperty(key: "location") {
                JSONString()
              }
              JSONProperty(key: "isRaining") {
                JSONBoolean()
              }
              JSONProperty(key: "windSpeed") {
                JSONInteger()
              }
              JSONProperty(key: "precipitationAmount") {
                JSONNumber()
              }
            }
            .required(["temperature", "location", "isRaining", "windSpeed"])
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func arraysAndDictionaries() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperatures: [Double]
        let temperatureByLocation: [String: Double?]
      }
      """,
      expandedSource: """
      struct Weather {
        let temperatures: [Double]
        let temperatureByLocation: [String: Double?]

        static var schema: JSONSchemaComponent {
          JSONObject {
            JSONProperty(key: "temperatures") {
              JSONArray()
                .items {
                  JSONNumber()
                }
            }
            JSONProperty(key: "temperatureByLocation") {
              JSONObject()
                .additionalProperties {
                  JSONNumber()
                }
            }
          }
          .required(["temperatures", "temperatureByLocation"])
        }
      }

      extension Weather: Schemable {
      }
      """,
      macros: testMacros
    )
  }

  @Test func multipleBindings() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let isRaining: Bool?, temperature: Int?, location: String
      }
      """,
      expandedSource: """
      struct Weather {
        let isRaining: Bool?, temperature: Int?, location: String

        static var schema: JSONSchemaComponent {
          JSONObject {
            JSONProperty(key: "isRaining") {
              JSONBoolean()
            }
            JSONProperty(key: "temperature") {
              JSONInteger()
            }
            JSONProperty(key: "location") {
              JSONString()
            }
          }
          .required(["location"])
        }
      }

      extension Weather: Schemable {
      }
      """,
      macros: testMacros
    )
  }
}

struct SchemaOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
    "SchemaOptions": SchemaOptionsMacro.self,
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
}

struct NumberOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
  ]

  @Test func numberOptions() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @NumberOptions(minimum: 0, maximum: 100)
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
                .minimum(0)
                .maximum(100)
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
}
