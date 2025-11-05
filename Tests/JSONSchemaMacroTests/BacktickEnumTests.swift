import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

@Suite struct BacktickEnumTests {
  let testMacros: [String: Macro.Type] = ["Schemable": SchemableMacro.self]

  @Test func backtickCasesWithoutRawValues() {
    assertMacroExpansion(
      """
      @Schemable
      enum Keywords {
        case `default`
        case `public`
        case normal
      }
      """,
      expandedSource: """
        enum Keywords {
          case `default`
          case `public`
          case normal

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Keywords> {
            JSONString()
              .enumValues {
                "default"
                "public"
                "normal"
              }
              .compactMap {
                switch $0 {
                case "default":
                  return Self.`default`
                case "public":
                  return Self.`public`
                case "normal":
                  return Self.normal
                default:
                  return nil
                }
              }
          }
        }

        extension Keywords: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func backtickCasesWithRawValues() {
    assertMacroExpansion(
      """
      @Schemable
      enum Keywords: String {
        case `default` = "default_value"
        case `public`
        case normal
      }
      """,
      expandedSource: """
        enum Keywords: String {
          case `default` = "default_value"
          case `public`
          case normal

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Keywords> {
            JSONString()
              .enumValues {
                "default_value"
                "public"
                "normal"
              }
              .compactMap {
                switch $0 {
                case "default_value":
                  return Self.`default`
                case "public":
                  return Self.`public`
                case "normal":
                  return Self.normal
                default:
                  return nil
                }
              }
          }
        }

        extension Keywords: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
