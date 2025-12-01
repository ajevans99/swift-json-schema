import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

@Suite struct SchemableEnumExpansionTests {
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<TemperatureKind> {
            JSONString()
              .enumValues {
                "celsius"
                "fahrenheit"
              }
              .compactMap {
                switch $0 {
                case "celsius":
                  return Self.celsius
                case "fahrenheit":
                  return Self.fahrenheit
                default:
                  return nil
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<TemperatureKind> {
            JSONComposition.OneOf(into: TemperatureKind.self) {
              JSONObject {
                JSONProperty(key: "cloudy") {
                  JSONObject {
                    JSONProperty(key: "coverage") {
                      JSONNumber()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.cloudy(coverage: $0)
                }
              JSONObject {
                JSONProperty(key: "rainy") {
                  JSONObject {
                    JSONProperty(key: "chanceOfRain") {
                      JSONNumber()
                    }
                      .required()
                    JSONProperty(key: "amount") {
                      JSONNumber()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.rainy(chanceOfRain: $0, amount: $1)
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

  @Test func associatedValuesAnyOfComposition() {
    assertMacroExpansion(
      """
      @Schemable(enumComposition: .anyOf)
      enum ServiceResponse {
        case success(message: String)
        case failure(code: Int)
      }
      """,
      expandedSource: """
        enum ServiceResponse {
          case success(message: String)
          case failure(code: Int)

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<ServiceResponse> {
            JSONComposition.AnyOf(into: ServiceResponse.self) {
              JSONObject {
                JSONProperty(key: "success") {
                  JSONObject {
                    JSONProperty(key: "message") {
                      JSONString()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.success(message: $0)
                }
              JSONObject {
                JSONProperty(key: "failure") {
                  JSONObject {
                    JSONProperty(key: "code") {
                      JSONInteger()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.failure(code: $0)
                }
            }
          }
        }

        extension ServiceResponse: Schemable {
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<TemperatureKind> {
            JSONComposition.OneOf(into: TemperatureKind.self) {
              JSONObject {
                JSONProperty(key: "cloudy") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONNumber()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.cloudy($0)
                }
              JSONObject {
                JSONProperty(key: "rainy") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONNumber()
                    }
                      .required()
                    JSONProperty(key: "_1") {
                      JSONNumber()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.rainy($0, $1)
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
        case rainy(chanceOfRain: Double, amount: Double?)
        case snowy
        case windy
        case stormy
      }
      """,
      expandedSource: """
        enum TemperatureKind {
          case cloudy(Double)
          case rainy(chanceOfRain: Double, amount: Double?)
          case snowy
          case windy
          case stormy

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<TemperatureKind> {
            JSONComposition.OneOf(into: TemperatureKind.self) {
              JSONObject {
                JSONProperty(key: "cloudy") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONNumber()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.cloudy($0)
                }
              JSONObject {
                JSONProperty(key: "rainy") {
                  JSONObject {
                    JSONProperty(key: "chanceOfRain") {
                      JSONNumber()
                    }
                      .required()
                    JSONProperty(key: "amount") {
                      JSONNumber()
                    }
                  }
                }
                  .required()
              }
                .map {
                  Self.rainy(chanceOfRain: $0, amount: $1)
                }
              JSONString()
                  .enumValues {
                    "snowy"
                    "windy"
                    "stormy"
                  }
                  .compactMap {
                    switch $0 {
                    case "snowy":
                      return Self.snowy
                    case "windy":
                      return Self.windy
                    case "stormy":
                      return Self.stormy
                    default:
                      return nil
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<UserProfileSetting> {
            JSONComposition.OneOf(into: UserProfileSetting.self) {
              JSONObject {
                JSONProperty(key: "username") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONString()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.username($0)
                }
              JSONObject {
                JSONProperty(key: "age") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONInteger()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.age($0)
                }
              JSONObject {
                JSONProperty(key: "preferredLanguages") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONArray {
                          JSONString()
                        }
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.preferredLanguages($0)
                }
              JSONObject {
                JSONProperty(key: "contactInfo") {
                  JSONObject {
                    JSONProperty(key: "_0") {
                      JSONObject()
                        .additionalProperties {
                          JSONString()
                        }
                        .map(\\.1)
                        .map(\\.matches)
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.contactInfo($0)
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
        case passengerInfo(name: String = "Unknown", seatNumber: String? = nil)
      }
      """,
      expandedSource: """
        enum FlightInfo {
          case flightNumber(_ value: Int = 0)
          case departureDetails(city: String = "Unknown", isInternational: Bool = false)
          case arrivalDetails(city: String = "Unknown")
          case passengerInfo(name: String = "Unknown", seatNumber: String? = nil)

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<FlightInfo> {
            JSONComposition.OneOf(into: FlightInfo.self) {
              JSONObject {
                JSONProperty(key: "flightNumber") {
                  JSONObject {
                    JSONProperty(key: "_") {
                      JSONInteger()
                        .default(0)
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.flightNumber($0)
                }
              JSONObject {
                JSONProperty(key: "departureDetails") {
                  JSONObject {
                    JSONProperty(key: "city") {
                      JSONString()
                        .default("Unknown")
                    }
                      .required()
                    JSONProperty(key: "isInternational") {
                      JSONBoolean()
                        .default(false)
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.departureDetails(city: $0, isInternational: $1)
                }
              JSONObject {
                JSONProperty(key: "arrivalDetails") {
                  JSONObject {
                    JSONProperty(key: "city") {
                      JSONString()
                        .default("Unknown")
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.arrivalDetails(city: $0)
                }
              JSONObject {
                JSONProperty(key: "passengerInfo") {
                  JSONObject {
                    JSONProperty(key: "name") {
                      JSONString()
                        .default("Unknown")
                    }
                      .required()
                    JSONProperty(key: "seatNumber") {
                      JSONString()
                        .default(nil)
                    }
                  }
                }
                  .required()
              }
                .map {
                  Self.passengerInfo(name: $0, seatNumber: $1)
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

  @Test func nestedEnumAndNonprimitiveType() {
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Category> {
            JSONString()
              .enumValues {
                "fiction"
                "nonFiction"
                "science"
                "history"
                "kids"
                "entertainment"
              }
              .compactMap {
                switch $0 {
                case "fiction":
                  return Self.fiction
                case "nonFiction":
                  return Self.nonFiction
                case "science":
                  return Self.science
                case "history":
                  return Self.history
                case "kids":
                  return Self.kids
                case "entertainment":
                  return Self.entertainment
                default:
                  return nil
                }
              }
          }
        }
        enum LibraryItem {
          case book(details: ItemDetails, category: Category)
          case movie(details: ItemDetails, category: Category, duration: Int)
          case music(details: ItemDetails, category: Category)

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<LibraryItem> {
            JSONComposition.OneOf(into: LibraryItem.self) {
              JSONObject {
                JSONProperty(key: "book") {
                  JSONObject {
                    JSONProperty(key: "details") {
                      ItemDetails.schema
                    }
                      .required()
                    JSONProperty(key: "category") {
                      Category.schema
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.book(details: $0, category: $1)
                }
              JSONObject {
                JSONProperty(key: "movie") {
                  JSONObject {
                    JSONProperty(key: "details") {
                      ItemDetails.schema
                    }
                      .required()
                    JSONProperty(key: "category") {
                      Category.schema
                    }
                      .required()
                    JSONProperty(key: "duration") {
                      JSONInteger()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.movie(details: $0, category: $1, duration: $2)
                }
              JSONObject {
                JSONProperty(key: "music") {
                  JSONObject {
                    JSONProperty(key: "details") {
                      ItemDetails.schema
                    }
                      .required()
                    JSONProperty(key: "category") {
                      Category.schema
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.music(details: $0, category: $1)
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

  @Test(arguments: ["public", "internal", "fileprivate", "package", "private"])
  func accessModifiers(_ modifier: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(modifier) enum TemperatureKind {
        case celsius
        case fahrenheit
      }
      """,
      expandedSource: """
        \(modifier) enum TemperatureKind {
          case celsius
          case fahrenheit

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          \(modifier) static var schema: some JSONSchemaComponent<TemperatureKind> {
            JSONString()
              .enumValues {
                "celsius"
                "fahrenheit"
              }
              .compactMap {
                switch $0 {
                case "celsius":
                  return Self.celsius
                case "fahrenheit":
                  return Self.fahrenheit
                default:
                  return nil
                }
              }
          }
        }

        \(modifier == "private" || modifier == "fileprivate" ? "\(modifier) " : "")extension TemperatureKind: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func documentedAssociatedValues() {
    assertMacroExpansion(
      """
      @Schemable
      enum Configuration {
        case database(
          /// The database connection URL
          url: String
        )
      }
      """,
      expandedSource: """
        enum Configuration {
          case database(
            /// The database connection URL
            url: String
          )

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Configuration> {
            JSONComposition.OneOf(into: Configuration.self) {
              JSONObject {
                JSONProperty(key: "database") {
                  JSONObject {
                    JSONProperty(key: "url") {
                      JSONString()
                        .description("The database connection URL")
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.database(url: $0)
                }
            }
          }
        }

        extension Configuration: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func mixedDocumentedAssociatedValues() {
    assertMacroExpansion(
      """
      @Schemable
      enum MixedConfig {
        case server(
          /// The server hostname
          host: String,
          port: Int
        )
      }
      """,
      expandedSource: """
        enum MixedConfig {
          case server(
            /// The server hostname
            host: String,
            port: Int
          )

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<MixedConfig> {
            JSONComposition.OneOf(into: MixedConfig.self) {
              JSONObject {
                JSONProperty(key: "server") {
                  JSONObject {
                    JSONProperty(key: "host") {
                      JSONString()
                        .description("The server hostname")
                    }
                      .required()
                    JSONProperty(key: "port") {
                      JSONInteger()
                    }
                      .required()
                  }
                }
                  .required()
              }
                .map {
                  Self.server(host: $0, port: $1)
                }
            }
          }
        }

        extension MixedConfig: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
