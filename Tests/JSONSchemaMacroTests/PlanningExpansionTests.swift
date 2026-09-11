import JSONSchemaMacro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct PlanningExpansionTests {
  let macros: [String: Macro.Type] = ["Schemable": SchemableMacro.self]

  @Test func explicitOptionalSpellingUsesScalarNullStyle() {
    assertMacroExpansion(
      """
      @Schemable
      struct Example {
        let name: Swift.Optional<Swift.String>
      }
      """,
      expandedSource: """
        struct Example {
          let name: Swift.Optional<Swift.String>

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Example> {
            JSONSchema(Example.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension Example: Schemable {
        }
        """,
      macros: macros
    )
  }

  @Test func unsupportedEnumCaseIsDiagnosedWithoutPartialPayloadMapping() {
    assertMacroExpansion(
      """
      @Schemable
      enum Event {
        case invalid(name: String, callback: () -> Void)
        case ready
      }
      """,
      expandedSource: """
        enum Event {
          case invalid(name: String, callback: () -> Void)
          case ready

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Event> {
            JSONString()
              .enumValues {
                "ready"
              }
              .compactMap {
                switch $0 {
                case "ready":
                  return Self.ready
                default:
                  return nil
                }
              }
          }
        }

        extension Event: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Enum case 'invalid' has unsupported associated value type '() -> Void'; the case cannot be included in the generated schema",
          line: 3,
          column: 40,
          severity: .error
        )
      ],
      macros: macros
    )
  }
}
