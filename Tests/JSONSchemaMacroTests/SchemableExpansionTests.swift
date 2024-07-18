import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct SchemableExpansionTests {
  let testMacros: [String: Macro.Type] = ["Schemable": SchemableMacro.self]

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
              JSONProperty(key: "humidity") {
                JSONNumber()
              }
            }
            .required(["temperature", "location", "isRaining", "windSpeed", "humidity"])
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
              JSONProperty(key: "conditionsByLocation") {
                JSONObject()
                  .additionalProperties {
                    WeatherCondition.schema
                  }
              }
            }
            .required(["temperatures", "temperatureByLocation", "conditionsByLocation"])
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func alternativeArraysAndDictionaries(declarationType: String) {
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

          static var schema: JSONSchemaComponent {
            JSONObject {
              JSONProperty(key: "temperature") {
                JSONNumber()
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

  @Test func nestedSchemableType() {
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

          static var schema: JSONSchemaComponent {
            JSONObject {
              JSONProperty(key: "temperature") {
                JSONNumber()
                  .default(72.0)
              }
              JSONProperty(key: "units") {
                TemperatureType.schema
              }
              JSONProperty(key: "location") {
                JSONString()
                  .default("Detroit")
              }
              JSONProperty(key: "isRaining") {
                JSONBoolean()
                  .default(false)
              }
              JSONProperty(key: "windSpeed") {
                JSONInteger()
                  .default(12)
              }
              JSONProperty(key: "precipitationAmount") {
                JSONNumber()
                  .default(nil)
              }
              JSONProperty(key: "humidity") {
                JSONNumber()
                  .default(0.30)
              }
            }
            .required(["temperature", "units", "location", "isRaining", "windSpeed", "humidity"])
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultValue() {

  }

  @Test(.disabled("TODO: Test diagnostics.")) func `enum`() {
    assertMacroExpansion(
      """
      @Schemable
      enum TempertureKind {
        case celsius
        case fahrenheit
      }
      """,
      expandedSource: """
        enum TempertureKind {
          case celsius
          case fahrenheit
        }
        """,
      macros: testMacros
    )
  }
}
