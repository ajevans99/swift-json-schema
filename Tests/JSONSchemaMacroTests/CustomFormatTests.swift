import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct CustomFormatTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "SchemaOptions": SchemaOptionsMacro.self,
  ]

  @Test func uuidFormat() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        @SchemaOptions(.format("uuid"))
        let id: UUID
      }
      """,
      expandedSource: """
        struct Person {
          let id: UUID

          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "id") {
                  JSONSchema({
                      UUID(uuidString: $0)!
                    }) {
                    JSONString()
                    .format("uuid")
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
      macros: testMacros
    )
  }

  @Test func dateTimeFormat() {
    assertMacroExpansion(
      """
      @Schemable
      struct Event {
        @SchemaOptions(.format("date-time"))
        let createdAt: Date
      }
      """,
      expandedSource: """
        struct Event {
          let createdAt: Date

          static var schema: some JSONSchemaComponent<Event> {
            JSONSchema(Event.init) {
              JSONObject {
                JSONProperty(key: "createdAt") {
                  JSONSchema({
                      ISO8601DateFormatter().date(from: $0)!
                    }) {
                    JSONString()
                    .format("date-time")
                  }
                }
                .required()
              }
            }
          }
        }

        extension Event: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func formatWithOtherOptions() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        @SchemaOptions(.format("uuid"), .description("Unique identifier"))
        let id: UUID
      }
      """,
      expandedSource: """
        struct Person {
          let id: UUID

          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "id") {
                  JSONSchema({
                      UUID(uuidString: $0)!
                    }) {
                    JSONString()
                    .format("uuid")
                    .description("Unique identifier")
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
      macros: testMacros
    )
  }

  @Test func formatWithCustomKey() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        @SchemaOptions(.format("uuid"), .key("userId"))
        let id: UUID
      }
      """,
      expandedSource: """
        struct Person {
          let id: UUID

          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "userId") {
                  JSONSchema({
                      UUID(uuidString: $0)!
                    }) {
                    JSONString()
                    .format("uuid")
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
      macros: testMacros
    )
  }

  @Test func formatWithOptionalType() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        @SchemaOptions(.format("uuid"))
        let id: UUID?
      }
      """,
      expandedSource: """
        struct Person {
          let id: UUID?

          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "id") {
                  JSONSchema({
                      UUID(uuidString: $0)!
                    }) {
                    JSONString()
                    .format("uuid")
                  }
                }
              }
            }
          }
        }

        extension Person: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}