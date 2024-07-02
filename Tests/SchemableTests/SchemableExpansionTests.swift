import JSONSchemaMacros
import SwiftSyntaxMacros
import Testing

struct SchemableExpansionTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
  ]

  @Test
  func basic() {
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
      
        static let schema = 1
      }
      """,
      macros: testMacros
    )
  }
}
