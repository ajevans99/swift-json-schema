import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct NumberOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "NumberOptions": NumberOptionsMacro.self,
  ]

  @Test func inclusiveMinimumMaximum() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @NumberOptions(.minimum(0), .maximum(100))
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
                  .minimum(0)
                  .maximum(100)
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

  @Test func exclusiveMinimumMaximum() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @NumberOptions(.exclusiveMinimum(0), .exclusiveMaximum(100))
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
                  .exclusiveMinimum(0)
                  .exclusiveMaximum(100)
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

  @Test func multipleOf() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @NumberOptions(.multipleOf(5))
        let temperature: Int
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Int

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONInteger()
                  .multipleOf(5)
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

struct ArrayOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "ArrayOptions": ArrayOptionsMacro.self,
  ]

  @Test func simple() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @ArrayOptions(
          .minContains(1),
          .maxContains(5),
          .minItems(2),
          .maxItems(10),
          .uniqueItems(true)
        )
        let temperatureReadings: [Double]
      }
      """,
      expandedSource: """
        struct Weather {
          let temperatureReadings: [Double]

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperatureReadings") {
                  JSONArray {
                    JSONNumber()
                  }
                  .minContains(1)
                  .maxContains(5)
                  .minItems(2)
                  .maxItems(10)
                  .uniqueItems(true)
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

struct ObjectOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "ObjectOptions": ObjectOptionsMacro.self,
  ]

  @Test func additionalProperties() {
    assertMacroExpansion(
      """
      @Schemable
      @ObjectOptions(.additionalProperties { false })
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
              .additionalProperties {
                false
              }
              // Drop the `AdditionalPropertiesParseResult` parse information. Use custom builder if needed.
              .map {
                $0.0
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

  @Test func patternProperties() {
    assertMacroExpansion(
      """
      @Schemable
      @ObjectOptions(.patternProperties {
        JSONProperty(key: "^[A-Za-z_][A-Za-z0-9_]*$") {
          JSONString()
        }
        .required()
      })
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
              .patternProperties {
                JSONProperty(key: "^[A-Za-z_][A-Za-z0-9_]*$") {
                  JSONString()
                }
                .required()
              }
              // Drop the `PatternPropertiesParseResult` parse information. Use custom builder if needed.
              .map {
                $0.0
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

  @Test func allObjectOptions() {
    assertMacroExpansion(
      """
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
              .minProperties(2)
              .maxProperties(5)
              .propertyNames {
                  JSONString()
                    .pattern("^[A-Za-z_][A-Za-z0-9_]*$")
              }
              .unevaluatedProperties {
                  JSONString()
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

struct StringOptionsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "StringOptions": StringOptionsMacro.self,
  ]

  @Test func simple() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @StringOptions(
          .minLength(5),
          .maxLength(100),
          .pattern("^[a-zA-Z]+$"),
          .format("city")
        )
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
                  .minLength(5)
                  .maxLength(100)
                  .pattern("^[a-zA-Z]+$")
                  .format("city")
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
