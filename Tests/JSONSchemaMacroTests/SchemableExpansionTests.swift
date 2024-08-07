import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct SchemableExpansionTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "ExcludeFromSchema": ExcludeFromSchemaMacro.self,
  ]

  @Test(arguments: ["struct", "class"]) func basicTypes(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let temperature: Double
        let location: String
        let isRaining: Bool
        let windSpeed: Int
        let precipitationAmount: Double?
        let humidity: Float
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let temperature: Double
          let location: String
          let isRaining: Bool
          let windSpeed: Int
          let precipitationAmount: Double?
          let humidity: Float

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                }
                .required()
                JSONProperty(key: "location") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                }
                .required()
                JSONProperty(key: "windSpeed") {
                  JSONInteger()
                }
                .required()
                JSONProperty(key: "precipitationAmount") {
                  JSONNumber()
                }
                JSONProperty(key: "humidity") {
                  JSONNumber()
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

  @Test(arguments: ["struct", "class"]) func arraysAndDictionaries(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let temperatures: [Double]
        let temperatureByLocation: [String: Double?]
        let conditionsByLocation: [String: WeatherCondition]
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let temperatures: [Double]
          let temperatureByLocation: [String: Double?]
          let conditionsByLocation: [String: WeatherCondition]

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperatures") {
                  JSONArray {
                    JSONNumber()
                  }
                }
                .required()
                JSONProperty(key: "temperatureByLocation") {
                  JSONObject()
                  .additionalProperties {
                    JSONNumber()
                  }
                }
                .required()
                JSONProperty(key: "conditionsByLocation") {
                  JSONObject()
                  .additionalProperties {
                    WeatherCondition.schema
                  }
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

  @Test(arguments: ["struct", "class"]) func alternativeArraysAndDictionaries(
    declarationType: String
  ) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let temperatures: Array<Double>
        let temperatureByLocation: Dictionary<String, Double?>
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let temperatures: Array<Double>
          let temperatureByLocation: Dictionary<String, Double?>

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperatures") {
                  JSONArray {
                    JSONNumber()
                  }
                }
                .required()
                JSONProperty(key: "temperatureByLocation") {
                  JSONObject()
                  .additionalProperties {
                    JSONNumber()
                  }
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

  @Test(arguments: ["struct", "class"]) func multipleBindings(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let isRaining: Bool?, temperature: Int?, location: String
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let isRaining: Bool?, temperature: Int?, location: String

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
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

  @Test func skipComputedProperties() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        var temperature: Double {
          didSet { print("Updated temperature") }
          willSet { print("Will update temperature") }
        }

        var temperatureInCelsius: Double {
          get { (temperature - 32) * 5 / 9 }
          set { temperature = newValue * 9 / 5 + 32 }
        }

        var isCold: Bool { temperature < 50 }
      }
      """,
      expandedSource: """
        struct Weather {
          var temperature: Double {
            didSet { print("Updated temperature") }
            willSet { print("Will update temperature") }
          }

          var temperatureInCelsius: Double {
            get { (temperature - 32) * 5 / 9 }
            set { temperature = newValue * 9 / 5 + 32 }
          }

          var isCold: Bool { temperature < 50 }

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
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

  @Test func defaultValue() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperature: Double = 72.0
        let units: TemperatureType = .fahrenheit
        let location: String = "Detroit"
        let isRaining: Bool = false
        let windSpeed: Int = 12
        let precipitationAmount: Double? = nil
        let humidity: Float = 0.30
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double = 72.0
          let units: TemperatureType = .fahrenheit
          let location: String = "Detroit"
          let isRaining: Bool = false
          let windSpeed: Int = 12
          let precipitationAmount: Double? = nil
          let humidity: Float = 0.30

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .default(72.0)
                }
                .required()
                JSONProperty(key: "units") {
                  TemperatureType.schema
                }
                .required()
                JSONProperty(key: "location") {
                  JSONString()
                  .default("Detroit")
                }
                .required()
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                  .default(false)
                }
                .required()
                JSONProperty(key: "windSpeed") {
                  JSONInteger()
                  .default(12)
                }
                .required()
                JSONProperty(key: "precipitationAmount") {
                  JSONNumber()
                  .default(nil)
                }
                JSONProperty(key: "humidity") {
                  JSONNumber()
                  .default(0.30)
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

  @Test func excludeFromSchema() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperature: Double
        @ExcludeFromSchema
        let units: TemperatureType
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double
          let units: TemperatureType

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
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
}
