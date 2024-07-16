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
}

struct NumberOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
    "NumberOptions": NumberOptionsMacro.self,
  ]

  @Test func inclusiveMinimumMaximum() {
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

  @Test func exclusiveMinimumMaximum() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @NumberOptions(exclusiveMinimum: 0, exclusiveMaximum: 100)
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
                .exclusiveMinimum(0)
                .exclusiveMaximum(100)
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

  @Test func multipleOf() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @NumberOptions(multipleOf: 5)
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
                .multipleOf(5)
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

struct ArrayOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
    "ArrayOptions": ArrayOptionsMacro.self,
  ]

  @Test func simple() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @ArrayOptions(
          minContains: 1,
          maxContains: 5,
          minItems: 2,
          maxItems: 10,
          uniqueItems: true
        )
        let temperatureReadings: [Double]
      }
      """,
      expandedSource: """
      struct Weather {
        let temperatureReadings: [Double]

        static var schema: JSONSchemaComponent {
          JSONObject {
            JSONProperty(key: "temperatureReadings") {
              JSONArray()
                .items {
                  JSONNumber()
                }
                .minContains(1)
                .maxContains(5)
                .minItems(2)
                .maxItems(10)
                .uniqueItems(true)
            }
          }
          .required(["temperatureReadings"])
        }
      }

      extension Weather: Schemable {
      }
      """,
      macros: testMacros
    )
  }
}

struct ObjectOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
    "ObjectOptions": ObjectOptionsMacro.self,
  ]

  @Test func basic() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @ObjectOptions(
          minProperties: 2,
          maxProperties: 5
        )
        let metadata: [String: String]
      }
      """,
      expandedSource: """
      struct Weather {
        let metadata: [String: String]

        static var schema: JSONSchemaComponent {
          JSONObject {
            JSONProperty(key: "metadata") {
              JSONObject()
                .additionalProperties {
                  JSONString()
                }
                .minProperties(2)
                .maxProperties(5)
            }
          }
          .required(["metadata"])
        }
      }

      extension Weather: Schemable {
      }
      """,
      macros: testMacros
    )
  }
}

struct StringOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
    "StringOptions": StringOptionsMacro.self,
  ]

  @Test func simple() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @StringOptions(
          minLength: 5,
          maxLength: 100,
          pattern: "^[a-zA-Z]+$",
          format: nil
        )
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
                .minLength(5)
                .maxLength(100)
                .pattern("^[a-zA-Z]+$")
                .format(nil)
            }
          }
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
