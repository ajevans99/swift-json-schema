import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

@Suite(.disabled()) struct SchemableEnumExpansionTests {
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

          static var schema: some JSONSchemaComponent<TemperatureKind> {
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

          static var schema: some JSONSchemaComponent<TemperatureKind> {
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

          static var schema: some JSONSchemaComponent<TemperatureKind> {
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

          static var schema: some JSONSchemaComponent<TemperatureKind> {
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

  @Test func arraysAndDictionaries() {
    assertMacroExpansion(
      """
      @Schemable
      enum UserProfileSetting {
        case username(String)
        case age(Int)
        case preferredLanguages([String])
        case contactInfo([String: String])
      }
      """,
      expandedSource: """
        enum UserProfileSetting {
          case username(String)
          case age(Int)
          case preferredLanguages([String])
          case contactInfo([String: String])

          static var schema: some JSONSchemaComponent<UserProfileSetting> {
            JSONComposition.AnyOf {
              JSONObject {
                JSONProperty(key: "username") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONString()
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "age") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONInteger()
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "preferredLanguages") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONArray()
                        .items {
                          JSONString()
                        }
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "contactInfo") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONObject()
                        .additionalProperties {
                          JSONString()
                        }
                    }
                  }
                }
              }
            }
          }
        }

        extension UserProfileSetting: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultValue() {
    assertMacroExpansion(
      """
      @Schemable
      enum FlightInfo {
        case flightNumber(_ value: Int = 0)
        case departureDetails(city: String = "Unknown", isInternational: Bool = false)
        case arrivalDetails(city: String = "Unknown")
        case passengerInfo(name: String = "Unknown", seatNumber: String = "Unknown")
      }
      """,
      expandedSource: """
        enum FlightInfo {
          case flightNumber(_ value: Int = 0)
          case departureDetails(city: String = "Unknown", isInternational: Bool = false)
          case arrivalDetails(city: String = "Unknown")
          case passengerInfo(name: String = "Unknown", seatNumber: String = "Unknown")

          static var schema: some JSONSchemaComponent<FlightInfo> {
            JSONComposition.AnyOf {
              JSONObject {
                JSONProperty(key: "flightNumber") {
                  JSONObject {
                    JSONProperty(key: "_") {
                      JSONInteger()
                        .default(0)
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "departureDetails") {
                  JSONObject {
                    JSONProperty(key: "city") {
                      JSONString()
                        .default("Unknown")
                    }
                    JSONProperty(key: "isInternational") {
                      JSONBoolean()
                        .default(false)
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "arrivalDetails") {
                  JSONObject {
                    JSONProperty(key: "city") {
                      JSONString()
                        .default("Unknown")
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "passengerInfo") {
                  JSONObject {
                    JSONProperty(key: "name") {
                      JSONString()
                        .default("Unknown")
                    }
                    JSONProperty(key: "seatNumber") {
                      JSONString()
                        .default("Unknown")
                    }
                  }
                }
              }
            }
          }
        }

        extension FlightInfo: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func nestedEnumAndNonPrimativeType() {
    assertMacroExpansion(
      """
      @Schemable
      enum Category {
        case fiction, nonFiction, science, history, kids, entertainment
      }
      @Schemable
      enum LibraryItem {
        case book(details: ItemDetails, category: Category)
        case movie(details: ItemDetails, category: Category, duration: Int)
        case music(details: ItemDetails, category: Category)
      }
      """,
      expandedSource: """
        enum Category {
          case fiction, nonFiction, science, history, kids, entertainment

          static var schema: some JSONSchemaComponent<Category> {
            JSONEnum {
              "fiction"
              "nonFiction"
              "science"
              "history"
              "kids"
              "entertainment"
            }
          }
        }
        enum LibraryItem {
          case book(details: ItemDetails, category: Category)
          case movie(details: ItemDetails, category: Category, duration: Int)
          case music(details: ItemDetails, category: Category)

          static var schema: some JSONSchemaComponent<LibraryItem> {
            JSONComposition.AnyOf {
              JSONObject {
                JSONProperty(key: "book") {
                  JSONObject {
                    JSONProperty(key: "details") {
                      ItemDetails.schema
                    }
                    JSONProperty(key: "category") {
                      Category.schema
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "movie") {
                  JSONObject {
                    JSONProperty(key: "details") {
                      ItemDetails.schema
                    }
                    JSONProperty(key: "category") {
                      Category.schema
                    }
                    JSONProperty(key: "duration") {
                      JSONInteger()
                    }
                  }
                }
              }
              JSONObject {
                JSONProperty(key: "music") {
                  JSONObject {
                    JSONProperty(key: "details") {
                      ItemDetails.schema
                    }
                    JSONProperty(key: "category") {
                      Category.schema
                    }
                  }
                }
              }
            }
          }
        }

        extension Category: Schemable {
        }

        extension LibraryItem: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
