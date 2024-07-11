import JSONSchemaMacros
import SwiftSyntaxMacros
import Testing

struct SchemableExpansionTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
  ]

  @Test
  func basic1() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperature: Double
        let location: String
      }
      """,
      expandedSource: """
      struct Weather {
        let temperature: Double
        let location: String
      
        static let schema: JSONSchemaRepresentable = JSONObject {
          JSONProperty(key: "temperature") {
            JSONNumber()
          }
          JSONProperty(key: "location") {
            JSONString()
          }
        }
      }

      extension Weather: Schemable {
      }
      """,
      macros: testMacros
    )
  }

  @Test
  func basic2() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperatures: [Double]
        let location: String = "Detroit"
      }
      """,
      expandedSource: """
      struct Weather {
        let temperatures: [Double]
        let temperatureByLocation: [String: Double]

        static let schema: JSONSchemaRepresentable = JSONObject {
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

      extension Weather: Schemable {
      }
      """,
      macros: testMacros
    )
  }
}
