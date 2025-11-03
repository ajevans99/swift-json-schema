import JSONSchemaMacro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct UnsupportedTypeDiagnosticsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self
  ]

  @Test func functionTypeNotSupported() {
    assertMacroExpansion(
      """
      @Schemable
      struct Handler {
        let name: String
        let callback: () -> Void
      }
      """,
      expandedSource: """
        struct Handler {
          let name: String
          let callback: () -> Void

          static var schema: some JSONSchemaComponent<Handler> {
            JSONSchema(Handler.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
              }
            }
          }
        }

        extension Handler: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Property 'callback' has type '() -> Void' which is not supported by the @Schemable macro. \
            This property will be excluded from the generated schema, which may cause the schema to not match \
            the memberwise initializer.
            """,
          line: 4,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  @Test func tupleTypeNotSupported() {
    assertMacroExpansion(
      """
      @Schemable
      struct Coordinates {
        let name: String
        let position: (x: Int, y: Int)
      }
      """,
      expandedSource: """
        struct Coordinates {
          let name: String
          let position: (x: Int, y: Int)

          static var schema: some JSONSchemaComponent<Coordinates> {
            JSONSchema(Coordinates.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
              }
            }
          }
        }

        extension Coordinates: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Property 'position' has type '(x: Int, y: Int)' which is not supported by the @Schemable macro. \
            This property will be excluded from the generated schema, which may cause the schema to not match \
            the memberwise initializer.
            """,
          line: 4,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  @Test func metatypeNotSupported() {
    assertMacroExpansion(
      """
      @Schemable
      struct Container {
        let name: String
        let type: Any.Type
      }
      """,
      expandedSource: """
        struct Container {
          let name: String
          let type: Any.Type

          static var schema: some JSONSchemaComponent<Container> {
            JSONSchema(Container.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
              }
            }
          }
        }

        extension Container: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Property 'type' has type 'Any.Type' which is not supported by the @Schemable macro. \
            This property will be excluded from the generated schema, which may cause the schema to not match \
            the memberwise initializer.
            """,
          line: 4,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  @Test func multipleUnsupportedProperties() {
    assertMacroExpansion(
      """
      @Schemable
      struct Mixed {
        let name: String
        let callback: () -> Void
        let position: (Int, Int)
        let age: Int
      }
      """,
      expandedSource: """
        struct Mixed {
          let name: String
          let callback: () -> Void
          let position: (Int, Int)
          let age: Int

          static var schema: some JSONSchemaComponent<Mixed> {
            JSONSchema(Mixed.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "age") {
                  JSONInteger()
                }
                .required()
              }
            }
          }
        }

        extension Mixed: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Property 'callback' has type '() -> Void' which is not supported by the @Schemable macro. \
            This property will be excluded from the generated schema, which may cause the schema to not match \
            the memberwise initializer.
            """,
          line: 4,
          column: 7,
          severity: .warning
        ),
        DiagnosticSpec(
          message: """
            Property 'position' has type '(Int, Int)' which is not supported by the @Schemable macro. \
            This property will be excluded from the generated schema, which may cause the schema to not match \
            the memberwise initializer.
            """,
          line: 5,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  @Test func supportedTypesNoWarning() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        let name: String
        let age: Int
        let score: Double
        let tags: [String]
      }
      """,
      expandedSource: """
        struct Person {
          let name: String
          let age: Int
          let score: Double
          let tags: [String]

          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "age") {
                  JSONInteger()
                }
                .required()
                JSONProperty(key: "score") {
                  JSONNumber()
                }
                .required()
                JSONProperty(key: "tags") {
                  JSONArray {
                    JSONString()
                  }
                }
                .required()
              }
            }
          }
        }

        extension Person: Schemable {
        }
        """,
      diagnostics: [],
      macros: testMacros
    )
  }
}
