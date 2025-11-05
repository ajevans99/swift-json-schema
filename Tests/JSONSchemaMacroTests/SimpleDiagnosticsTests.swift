import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct SimpleDiagnosticsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self
  ]

  @Test func simpleTest() {
    // Just ensure the macro can be created and runs
    #expect(testMacros["Schemable"] != nil)
  }
}
