import JSONSchemaMacro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct InitializerDiagnosticsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self
  ]

  @Test func propertyWithDefaultValueEmitsDiagnostic() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        let name: String
        let age: Int = 0
      }
      """,
      expandedSource: """
        struct Person {
          let name: String
          let age: Int = 0

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "age") {
                  JSONInteger()
                  .default(0)
                }
                .required()
              }
            }
          }
        }

        extension Person: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'age' has a default value which will be excluded from the memberwise initializer",
          line: 4,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  @Test func allPropertiesWithDefaultValuesNoDiagnostic() {
    // When ALL properties have default values, the synthesized init() with no
    // parameters is intentional and valid, so no diagnostic should be emitted
    assertMacroExpansion(
      """
      @Schemable
      struct Config {
        let host: String = "localhost"
        let port: Int = 8080
        let timeout: Double = 30.0
      }
      """,
      expandedSource: """
        struct Config {
          let host: String = "localhost"
          let port: Int = 8080
          let timeout: Double = 30.0

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Config> {
            JSONSchema(Config.init) {
              JSONObject {
                JSONProperty(key: "host") {
                  JSONString()
                  .default("localhost")
                }
                .required()
                JSONProperty(key: "port") {
                  JSONInteger()
                  .default(8080)
                }
                .required()
                JSONProperty(key: "timeout") {
                  JSONNumber()
                  .default(30.0)
                }
                .required()
              }
            }
          }
        }

        extension Config: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func noDefaultValuesNoDiagnostics() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        struct Person {
          let name: String
          let age: Int

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

  @Test func explicitInitParameterOrderMismatch() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        let name: String
        let age: Int

        init(age: Int, name: String) {
          self.name = name
          self.age = age
        }
      }
      """,
      expandedSource: """
        struct Person {
          let name: String
          let age: Int

          init(age: Int, name: String) {
            self.name = name
            self.age = age
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
              }
            }
          }
        }

        extension Person: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Initializer parameter at position 1 is 'age' but schema expects 'name'. The schema will generate properties in a different order than the initializer parameters.",
          line: 6,
          column: 8,
          severity: .error
        ),
        DiagnosticSpec(
          message:
            "Initializer parameter at position 2 is 'name' but schema expects 'age'. The schema will generate properties in a different order than the initializer parameters.",
          line: 6,
          column: 18,
          severity: .error
        ),
      ],
      macros: testMacros
    )
  }

  @Test func explicitInitTypeMismatch() {
    assertMacroExpansion(
      """
      @Schemable
      struct Product {
        let name: String
        let price: Double
        let quantity: Int

        init(name: String, price: Int, quantity: Double) {
          self.name = name
          self.price = Double(price)
          self.quantity = Int(quantity)
        }
      }
      """,
      expandedSource: """
        struct Product {
          let name: String
          let price: Double
          let quantity: Int

          init(name: String, price: Int, quantity: Double) {
            self.name = name
            self.price = Double(price)
            self.quantity = Int(quantity)
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Product> {
            JSONSchema(Product.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "price") {
                  JSONNumber()
                }
                .required()
                JSONProperty(key: "quantity") {
                  JSONInteger()
                }
                .required()
              }
            }
          }
        }

        extension Product: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Parameter 'price' has type 'Int' but schema expects 'Double'. This type mismatch will cause the generated schema to fail.",
          line: 7,
          column: 29,
          severity: .error
        ),
        DiagnosticSpec(
          message:
            "Parameter 'quantity' has type 'Double' but schema expects 'Int'. This type mismatch will cause the generated schema to fail.",
          line: 7,
          column: 44,
          severity: .error
        ),
      ],
      macros: testMacros
    )
  }

  @Test func noMatchingInitWithExcludedProperties() {
    assertMacroExpansion(
      """
      @Schemable
      struct Config {
        let host: String
        let port: Int

        @ExcludeFromSchema
        let internalFlag: Bool

        init(host: String, port: Int, internalFlag: Bool) {
          self.host = host
          self.port = port
          self.internalFlag = internalFlag
        }
      }
      """,
      expandedSource: """
        struct Config {
          let host: String
          let port: Int

          @ExcludeFromSchema
          let internalFlag: Bool

          init(host: String, port: Int, internalFlag: Bool) {
            self.host = host
            self.port = port
            self.internalFlag = internalFlag
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Config> {
            JSONSchema(Config.init) {
              JSONObject {
                JSONProperty(key: "host") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "port") {
                  JSONInteger()
                }
                .required()
              }
            }
          }
        }

        extension Config: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Type 'Config' has explicit initializers, but none match the expected schema signature.

            Expected: init(host: String, port: Int)

            Available initializers:
              - init(host: String, port: Int, internalFlag: Bool)

            Note: The following properties are excluded from the schema using @ExcludeFromSchema: 'internalFlag'
            These will still be present in the memberwise initializer but not in the schema.

            The generated schema expects JSONSchema(Config.init) to use an initializer that matches all schema properties. Consider adding a matching initializer or adjusting the schema properties.
            """,
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  @Test func matchingExplicitInitWithExcludedProperties() {
    assertMacroExpansion(
      """
      @Schemable
      struct Config {
        let host: String
        let port: Int

        @ExcludeFromSchema
        let internalFlag: Bool = false

        init(host: String, port: Int) {
          self.host = host
          self.port = port
        }
      }
      """,
      expandedSource: """
        struct Config {
          let host: String
          let port: Int

          @ExcludeFromSchema
          let internalFlag: Bool = false

          init(host: String, port: Int) {
            self.host = host
            self.port = port
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Config> {
            JSONSchema(Config.init) {
              JSONObject {
                JSONProperty(key: "host") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "port") {
                  JSONInteger()
                }
                .required()
              }
            }
          }
        }

        extension Config: Schemable {
        }
        """,
      diagnostics: [],
      macros: testMacros
    )
  }
}
