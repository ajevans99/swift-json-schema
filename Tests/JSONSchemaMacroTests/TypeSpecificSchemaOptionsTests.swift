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
    "Schemable": SchemableMacro.self, "ArrayOptions": ArrayOptionsMacro.self,
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
    "Schemable": SchemableMacro.self, "ObjectOptions": ObjectOptionsMacro.self,
  ]

  @Test func basic() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        @ObjectOptions(
          propertyNames: .options(pattern: "^[A-Za-z_][A-Za-z0-9_]*$"),
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
                  .propertyNames(.options(pattern: "^[A-Za-z_][A-Za-z0-9_]*$"))
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

  @Test func onStructDeclaration() {
    assertMacroExpansion(
      """
      @ObjectOptions(
        minProperties: 2,
        maxProperties: 5
      )
      @Schemable
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
            .minProperties(2)
            .maxProperties(5)
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
