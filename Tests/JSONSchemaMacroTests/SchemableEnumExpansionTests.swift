import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct SchemableEnumExpansionTests {
  let testMacros: [String: Macro.Type] = ["Schemable": SchemableMacro.self]

  @Test func basic() {
    assertMacroExpansion(
      """
      @Schemable
      enum TemperatureKind {
        case celsius
        case fahrenheit
      }
      """,
      expandedSource: """
        enum TemperatureKind {
          case celsius
          case fahrenheit

          static var schema: JSONSchemaComponent {
            JSONEnum {
              "celsius"
              "fahrenheit"
            }
          }
        }

        extension TemperatureKind: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func associatedValues() {
    assertMacroExpansion(
      """
      @Schemable
      enum TemperatureKind {
        case cloudy(coverage: Double)
        case rainy(chanceOfRain: Double, amount: Double)
      }
      """,
      expandedSource: """
        enum TemperatureKind {
          case cloudy(coverage: Double)
          case rainy(chanceOfRain: Double, amount: Double)

          static var schema: JSONSchemaComponent {
            JSONComposition.AnyOf {
              JSONObject {
                JSONProperty(key: "cloudy") {
                  JSONObject {
                    JSONProperty(key: "coverage") {
                      JSONNumber()
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "rainy") {
                  JSONObject {
                    JSONProperty(key: "chanceOfRain") {
                      JSONNumber()
                    }
                    JSONProperty(key: "amount") {
                      JSONNumber()
                    }
                  }
                }
              }
            }
          }
        }

        extension TemperatureKind: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func unlabeledAssociatedValues() {
    assertMacroExpansion(
      """
      @Schemable
      enum TemperatureKind {
        case cloudy(Double)
        case rainy(Double, Double)
      }
      """,
      expandedSource: """
        enum TemperatureKind {
          case cloudy(Double)
          case rainy(Double, Double)

          static var schema: JSONSchemaComponent {
            JSONComposition.AnyOf {
              JSONObject {
                JSONProperty(key: "cloudy") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONNumber()
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "rainy") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONNumber()
                    }
                    JSONProperty(key: "_1") {
                      JSONNumber()
                    }
                  }
                }
              }
            }
          }
        }

        extension TemperatureKind: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func mixed() {
    assertMacroExpansion(
      """
      @Schemable
      enum TemperatureKind {
        case cloudy(Double)
        case rainy(chanceOfRain: Double, amount: Double)
        case snowy
        case windy
        case stormy
      }
      """,
      expandedSource: """
        enum TemperatureKind {
          case cloudy(Double)
          case rainy(chanceOfRain: Double, amount: Double)
          case snowy
          case windy
          case stormy

          static var schema: JSONSchemaComponent {
            JSONComposition.AnyOf {
              JSONObject {
                JSONProperty(key: "cloudy") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONNumber()
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "rainy") {
                  JSONObject {
                    JSONProperty(key: "chanceOfRain") {
                      JSONNumber()
                    }
                    JSONProperty(key: "amount") {
                      JSONNumber()
                    }
                  }
                }
              }
              JSONEnum {
                "snowy"
                "windy"
                "stormy"
              }
            }
          }
        }

        extension TemperatureKind: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
