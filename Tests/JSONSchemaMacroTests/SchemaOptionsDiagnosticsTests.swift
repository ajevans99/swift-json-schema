import JSONSchemaMacro
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct SchemaOptionsDiagnosticsTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
    "SchemaOptions": SchemaOptionsMacro.self,
    "StringOptions": StringOptionsMacro.self,
    "NumberOptions": NumberOptionsMacro.self,
    "ArrayOptions": ArrayOptionsMacro.self,
    "ObjectOptions": ObjectOptionsMacro.self,
  ]

  // MARK: - Type Mismatch Tests

  @Test func stringOptionsOnIntProperty() {
    assertMacroExpansion(
      """
      @Schemable
      struct Person {
        @StringOptions(.minLength(5))
        let age: Int
      }
      """,
      expandedSource: """
        struct Person {
          let age: Int

          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "age") {
                  JSONInteger()
                  .minLength(5)
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
          message: "@StringOptions can only be used on String properties, but 'age' has type 'Int'",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  @Test func numberOptionsOnStringProperty() {
    assertMacroExpansion(
      """
      @Schemable
      struct Product {
        @NumberOptions(.minimum(0))
        let name: String
      }
      """,
      expandedSource: """
        struct Product {
          let name: String

          static var schema: some JSONSchemaComponent<Product> {
            JSONSchema(Product.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                  .minimum(0)
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
            "@NumberOptions can only be used on numeric (Int, Double, etc.) properties, but 'name' has type 'String'",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  @Test func arrayOptionsOnNonArrayProperty() {
    assertMacroExpansion(
      """
      @Schemable
      struct Data {
        @ArrayOptions(.minItems(1))
        let count: Int
      }
      """,
      expandedSource: """
        struct Data {
          let count: Int

          static var schema: some JSONSchemaComponent<Data> {
            JSONSchema(Data.init) {
              JSONObject {
                JSONProperty(key: "count") {
                  JSONInteger()
                  .minItems(1)
                }
                .required()
              }
            }
          }
        }

        extension Data: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@ArrayOptions can only be used on Array properties, but 'count' has type 'Int'",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - Min > Max Constraint Tests

  @Test func stringMinLengthGreaterThanMaxLength() {
    assertMacroExpansion(
      """
      @Schemable
      struct User {
        @StringOptions(.minLength(10), .maxLength(5))
        let username: String
      }
      """,
      expandedSource: """
        struct User {
          let username: String

          static var schema: some JSONSchemaComponent<User> {
            JSONSchema(User.init) {
              JSONObject {
                JSONProperty(key: "username") {
                  JSONString()
                  .minLength(10)
                  .maxLength(5)
                }
                .required()
              }
            }
          }
        }

        extension User: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'username' has minLength (10) greater than maxLength (5). This string length constraint can never be satisfied.",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  @Test func numberMinimumGreaterThanMaximum() {
    assertMacroExpansion(
      """
      @Schemable
      struct Temperature {
        @NumberOptions(.minimum(100), .maximum(50))
        let celsius: Double
      }
      """,
      expandedSource: """
        struct Temperature {
          let celsius: Double

          static var schema: some JSONSchemaComponent<Temperature> {
            JSONSchema(Temperature.init) {
              JSONObject {
                JSONProperty(key: "celsius") {
                  JSONNumber()
                  .minimum(100)
                  .maximum(50)
                }
                .required()
              }
            }
          }
        }

        extension Temperature: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'celsius' has minimum (100) greater than maximum (50). This value constraint can never be satisfied.",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  @Test func arrayMinItemsGreaterThanMaxItems() {
    assertMacroExpansion(
      """
      @Schemable
      struct Collection {
        @ArrayOptions(.minItems(10), .maxItems(5))
        let items: [String]
      }
      """,
      expandedSource: """
        struct Collection {
          let items: [String]

          static var schema: some JSONSchemaComponent<Collection> {
            JSONSchema(Collection.init) {
              JSONObject {
                JSONProperty(key: "items") {
                  JSONArray {
                    JSONString()
                  }
                  .minItems(10)
                  .maxItems(5)
                }
                .required()
              }
            }
          }
        }

        extension Collection: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'items' has minItems (10) greater than maxItems (5). This array size constraint can never be satisfied.",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - Negative Value Tests

  @Test func negativeMinLength() {
    assertMacroExpansion(
      """
      @Schemable
      struct Data {
        @StringOptions(.minLength(-5))
        let text: String
      }
      """,
      expandedSource: """
        struct Data {
          let text: String

          static var schema: some JSONSchemaComponent<Data> {
            JSONSchema(Data.init) {
              JSONObject {
                JSONProperty(key: "text") {
                  JSONString()
                  .minLength(-5)
                }
                .required()
              }
            }
          }
        }

        extension Data: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'text' has minLength with negative value (-5). This constraint must be non-negative.",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  @Test func negativeMinItems() {
    assertMacroExpansion(
      """
      @Schemable
      struct List {
        @ArrayOptions(.minItems(-1))
        let values: [Int]
      }
      """,
      expandedSource: """
        struct List {
          let values: [Int]

          static var schema: some JSONSchemaComponent<List> {
            JSONSchema(List.init) {
              JSONObject {
                JSONProperty(key: "values") {
                  JSONArray {
                    JSONInteger()
                  }
                  .minItems(-1)
                }
                .required()
              }
            }
          }
        }

        extension List: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'values' has minItems with negative value (-1). This constraint must be non-negative.",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - ReadOnly/WriteOnly Conflict Tests

  @Test func readOnlyAndWriteOnlyConflict() {
    assertMacroExpansion(
      """
      @Schemable
      struct Data {
        @SchemaOptions(.readOnly(true), .writeOnly(true))
        let value: String
      }
      """,
      expandedSource: """
        struct Data {
          let value: String

          static var schema: some JSONSchemaComponent<Data> {
            JSONSchema(Data.init) {
              JSONObject {
                JSONProperty(key: "value") {
                  JSONString()
                  .readOnly(true)
                  .writeOnly(true)
                }
                .required()
              }
            }
          }
        }

        extension Data: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Property 'value' cannot be both readOnly and writeOnly",
          line: 4,
          column: 7,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - Conflicting Constraint Tests

  @Test func minimumAndExclusiveMinimumConflict() {
    assertMacroExpansion(
      """
      @Schemable
      struct Range {
        @NumberOptions(.minimum(0), .exclusiveMinimum(0))
        let value: Double
      }
      """,
      expandedSource: """
        struct Range {
          let value: Double

          static var schema: some JSONSchemaComponent<Range> {
            JSONSchema(Range.init) {
              JSONObject {
                JSONProperty(key: "value") {
                  JSONNumber()
                  .minimum(0)
                  .exclusiveMinimum(0)
                }
                .required()
              }
            }
          }
        }

        extension Range: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'value' has both minimum and exclusiveMinimum specified. Use only one of minimum or exclusiveMinimum.",
          line: 4,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  @Test func maximumAndExclusiveMaximumConflict() {
    assertMacroExpansion(
      """
      @Schemable
      struct Range {
        @NumberOptions(.maximum(100), .exclusiveMaximum(100))
        let value: Double
      }
      """,
      expandedSource: """
        struct Range {
          let value: Double

          static var schema: some JSONSchemaComponent<Range> {
            JSONSchema(Range.init) {
              JSONObject {
                JSONProperty(key: "value") {
                  JSONNumber()
                  .maximum(100)
                  .exclusiveMaximum(100)
                }
                .required()
              }
            }
          }
        }

        extension Range: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'value' has both maximum and exclusiveMaximum specified. Use only one of maximum or exclusiveMaximum.",
          line: 4,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - Duplicate Option Tests

  @Test func duplicateMinLengthOption() {
    assertMacroExpansion(
      """
      @Schemable
      struct Data {
        @StringOptions(.minLength(5), .minLength(10))
        let text: String
      }
      """,
      expandedSource: """
        struct Data {
          let text: String

          static var schema: some JSONSchemaComponent<Data> {
            JSONSchema(Data.init) {
              JSONObject {
                JSONProperty(key: "text") {
                  JSONString()
                  .minLength(5)
                  .minLength(10)
                }
                .required()
              }
            }
          }
        }

        extension Data: Schemable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "Property 'text' has minLength specified 2 times. Only the last value will be used.",
          line: 4,
          column: 7,
          severity: .warning
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - Valid Usage (No Diagnostics)

  @Test func validStringOptions() {
    assertMacroExpansion(
      """
      @Schemable
      struct User {
        @StringOptions(.minLength(5), .maxLength(20))
        let username: String
      }
      """,
      expandedSource: """
        struct User {
          let username: String

          static var schema: some JSONSchemaComponent<User> {
            JSONSchema(User.init) {
              JSONObject {
                JSONProperty(key: "username") {
                  JSONString()
                  .minLength(5)
                  .maxLength(20)
                }
                .required()
              }
            }
          }
        }

        extension User: Schemable {
        }
        """,
      diagnostics: [],
      macros: testMacros
    )
  }

  @Test func validNumberOptions() {
    assertMacroExpansion(
      """
      @Schemable
      struct Product {
        @NumberOptions(.minimum(0), .maximum(100))
        let price: Double
      }
      """,
      expandedSource: """
        struct Product {
          let price: Double

          static var schema: some JSONSchemaComponent<Product> {
            JSONSchema(Product.init) {
              JSONObject {
                JSONProperty(key: "price") {
                  JSONNumber()
                  .minimum(0)
                  .maximum(100)
                }
                .required()
              }
            }
          }
        }

        extension Product: Schemable {
        }
        """,
      diagnostics: [],
      macros: testMacros
    )
  }
}
