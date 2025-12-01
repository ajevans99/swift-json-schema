import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

/// Tests for optional null handling in the @Schemable macro
struct OptionalNullsExpansionTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self,
    "SchemaOptions": SchemaOptionsMacro.self,
  ]

  // MARK: - Per-property opt-in tests

  @Test func perPropertyOrNullTypeStyle() {
    assertMacroExpansion(
      """
      @Schemable
      struct User {
        let name: String

        @SchemaOptions(.orNull(style: .type))
        let age: Int?

        let email: String?
      }
      """,
      expandedSource: """
        struct User {
          let name: String
          let age: Int?

          let email: String?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<User> {
            JSONSchema(User.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "age") {
                  JSONInteger()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "email") {
                  JSONString()
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension User: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func perPropertyOrNullUnionStyle() {
    assertMacroExpansion(
      """
      @Schemable
      struct Product {
        @SchemaOptions(.orNull(style: .union))
        let tags: [String]?

        @SchemaOptions(.orNull(style: .union))
        let metadata: [String: String]?
      }
      """,
      expandedSource: """
        struct Product {
          let tags: [String]?
          let metadata: [String: String]?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Product> {
            JSONSchema(Product.init) {
              JSONObject {
                JSONProperty(key: "tags") {
                  JSONArray {
                    JSONString()
                  }
                  .orNull(style: .union)
                }
                .flatMapOptional()
                JSONProperty(key: "metadata") {
                  JSONObject()
                  .additionalProperties {
                    JSONString()
                  }
                  .map(\\.1)
                  .map(\\.matches)
                  .orNull(style: .union)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension Product: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func perPropertyMixedStyles() {
    assertMacroExpansion(
      """
      @Schemable
      struct MixedOptionals {
        @SchemaOptions(.orNull(style: .type))
        let count: Int?

        @SchemaOptions(.orNull(style: .union))
        let items: [String]?

        let description: String?
      }
      """,
      expandedSource: """
        struct MixedOptionals {
          let count: Int?
          let items: [String]?

          let description: String?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<MixedOptionals> {
            JSONSchema(MixedOptionals.init) {
              JSONObject {
                JSONProperty(key: "count") {
                  JSONInteger()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "items") {
                  JSONArray {
                    JSONString()
                  }
                  .orNull(style: .union)
                }
                .flatMapOptional()
                JSONProperty(key: "description") {
                  JSONString()
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension MixedOptionals: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func perPropertyAnyOfStyle() {
    assertMacroExpansion(
      """
      @Schemable
      struct CustomOptional {
        @SchemaOptions(.orNull(style: .unionAnyOf))
        let metadata: [String: String]?
      }
      """,
      expandedSource: """
        struct CustomOptional {
          let metadata: [String: String]?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<CustomOptional> {
            JSONSchema(CustomOptional.init) {
              JSONObject {
                JSONProperty(key: "metadata") {
                  JSONObject()
                  .additionalProperties {
                    JSONString()
                  }
                  .map(\\.1)
                  .map(\\.matches)
                  .orNull(style: .unionAnyOf)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension CustomOptional: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - Default behavior (null allowed by default)

  @Test func defaultBehaviorAllowsNull() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let location: String
        let temperature: Double?
        let humidity: Int?
        let isRaining: Bool?
        let windSpeed: Float?
      }
      """,
      expandedSource: """
        struct Weather {
          let location: String
          let temperature: Double?
          let humidity: Int?
          let isRaining: Bool?
          let windSpeed: Float?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "location") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "humidity") {
                  JSONInteger()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "windSpeed") {
                  JSONNumber()
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultUnionStyleCanEmitAnyOf() {
    assertMacroExpansion(
      """
      @Schemable(optionalNullUnion: .anyOf)
      struct FeatureFlag {
        let tags: [String]?
        let metadata: [String: String]?
      }
      """,
      expandedSource: """
        struct FeatureFlag {
          let tags: [String]?
          let metadata: [String: String]?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<FeatureFlag> {
            JSONSchema(FeatureFlag.init) {
              JSONObject {
                JSONProperty(key: "tags") {
                  JSONArray {
                    JSONString()
                  }
                  .orNull(style: .unionAnyOf)
                }
                .flatMapOptional()
                JSONProperty(key: "metadata") {
                  JSONObject()
                  .additionalProperties {
                    JSONString()
                  }
                  .map(\\.1)
                  .map(\\.matches)
                  .orNull(style: .unionAnyOf)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension FeatureFlag: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultAllowComplexTypes() {
    assertMacroExpansion(
      """
      @Schemable
      struct Product {
        let name: String
        let tags: [String]?
        let metadata: [String: Int]?
        let relatedProducts: [Product]?
      }
      """,
      expandedSource: """
        struct Product {
          let name: String
          let tags: [String]?
          let metadata: [String: Int]?
          let relatedProducts: [Product]?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Product> {
            JSONSchema(Product.init) {
              JSONObject {
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "tags") {
                  JSONArray {
                    JSONString()
                  }
                  .orNull(style: .union)
                }
                .flatMapOptional()
                JSONProperty(key: "metadata") {
                  JSONObject()
                  .additionalProperties {
                    JSONInteger()
                  }
                  .map(\\.1)
                  .map(\\.matches)
                  .orNull(style: .union)
                }
                .flatMapOptional()
                JSONProperty(key: "relatedProducts") {
                  JSONArray {
                    JSONDynamicReference<Self>()
                  }
                  .orNull(style: .union)
                }
                .flatMapOptional()
              }
              .dynamicAnchor(Self.defaultAnchor)
            }
          }
        }

        extension Product: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultAllowMixedTypes() {
    assertMacroExpansion(
      """
      @Schemable
      struct MixedTypes {
        let id: Int
        let count: Int?
        let tags: [String]?
        let score: Double?
        let metadata: [String: String]?
        let active: Bool?
      }
      """,
      expandedSource: """
        struct MixedTypes {
          let id: Int
          let count: Int?
          let tags: [String]?
          let score: Double?
          let metadata: [String: String]?
          let active: Bool?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<MixedTypes> {
            JSONSchema(MixedTypes.init) {
              JSONObject {
                JSONProperty(key: "id") {
                  JSONInteger()
                }
                .required()
                JSONProperty(key: "count") {
                  JSONInteger()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "tags") {
                  JSONArray {
                    JSONString()
                  }
                  .orNull(style: .union)
                }
                .flatMapOptional()
                JSONProperty(key: "score") {
                  JSONNumber()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "metadata") {
                  JSONObject()
                  .additionalProperties {
                    JSONString()
                  }
                  .map(\\.1)
                  .map(\\.matches)
                  .orNull(style: .union)
                }
                .flatMapOptional()
                JSONProperty(key: "active") {
                  JSONBoolean()
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension MixedTypes: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - Explicit false (opt-out of null acceptance)

  @Test func explicitFalsePolicy() {
    assertMacroExpansion(
      """
      @Schemable(optionalNulls: false)
      struct ForbidNull {
        let required: String
        let optional: Int?
      }
      """,
      expandedSource: """
        struct ForbidNull {
          let required: String
          let optional: Int?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<ForbidNull> {
            JSONSchema(ForbidNull.init) {
              JSONObject {
                JSONProperty(key: "required") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "optional") {
                  JSONInteger()
                }
              }
            }
          }
        }

        extension ForbidNull: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - Interaction with other SchemaOptions

  @Test func orNullWithOtherSchemaOptions() {
    assertMacroExpansion(
      """
      @Schemable
      struct UserProfile {
        @SchemaOptions(
          .orNull(style: .type),
          .description("User's age in years"),
          .default(nil)
        )
        let age: Int?

        @SchemaOptions(
          .orNull(style: .union),
          .title("Tags"),
          .description("User tags")
        )
        let tags: [String]?
      }
      """,
      expandedSource: """
        struct UserProfile {
          let age: Int?
          let tags: [String]?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<UserProfile> {
            JSONSchema(UserProfile.init) {
              JSONObject {
                JSONProperty(key: "age") {
                  JSONInteger()
                  .description("User's age in years")
                  .default(nil)
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "tags") {
                  JSONArray {
                    JSONString()
                  }
                  .title("Tags")
                  .description("User tags")
                  .orNull(style: .union)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension UserProfile: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultAllowWithPropertyOverride() {
    assertMacroExpansion(
      """
      @Schemable
      struct OverrideTest {
        let count: Int?

        @SchemaOptions(.description("Explicitly styled"))
        let score: Double?
      }
      """,
      expandedSource: """
        struct OverrideTest {
          let count: Int?
          let score: Double?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<OverrideTest> {
            JSONSchema(OverrideTest.init) {
              JSONObject {
                JSONProperty(key: "count") {
                  JSONInteger()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "score") {
                  JSONNumber()
                  .description("Explicitly styled")
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension OverrideTest: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - Edge cases

  @Test func defaultAllowWithNoOptionalProperties() {
    assertMacroExpansion(
      """
      @Schemable
      struct NoOptionals {
        let id: Int
        let name: String
      }
      """,
      expandedSource: """
        struct NoOptionals {
          let id: Int
          let name: String

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<NoOptionals> {
            JSONSchema(NoOptionals.init) {
              JSONObject {
                JSONProperty(key: "id") {
                  JSONInteger()
                }
                .required()
                JSONProperty(key: "name") {
                  JSONString()
                }
                .required()
              }
            }
          }
        }

        extension NoOptionals: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func defaultAllowWithKeyStrategy() {
    assertMacroExpansion(
      """
      @Schemable(keyStrategy: .snakeCase)
      struct SnakeCaseOptionals {
        let userId: Int
        let firstName: String?
        let lastName: String?
      }
      """,
      expandedSource: """
        struct SnakeCaseOptionals {
          let userId: Int
          let firstName: String?
          let lastName: String?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<SnakeCaseOptionals> {
            JSONSchema(SnakeCaseOptionals.init) {
              JSONObject {
                JSONProperty(key: SnakeCaseOptionals.keyEncodingStrategy.encode("userId")) {
                  JSONInteger()
                }
                .required()
                JSONProperty(key: SnakeCaseOptionals.keyEncodingStrategy.encode("firstName")) {
                  JSONString()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: SnakeCaseOptionals.keyEncodingStrategy.encode("lastName")) {
                  JSONString()
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var keyEncodingStrategy: KeyEncodingStrategies {
            .snakeCase
          }
        }

        extension SnakeCaseOptionals: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func optionalCustomType() {
    assertMacroExpansion(
      """
      @Schemable
      struct Container {
        let data: CustomData?
      }
      """,
      expandedSource: """
        struct Container {
          let data: CustomData?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Container> {
            JSONSchema(Container.init) {
              JSONObject {
                JSONProperty(key: "data") {
                  CustomData.schema
                  .orNull(style: .union)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension Container: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func nestedOptionalArrays() {
    assertMacroExpansion(
      """
      @Schemable
      struct NestedArrays {
        let matrix: [[Int]]?
      }
      """,
      expandedSource: """
        struct NestedArrays {
          let matrix: [[Int]]?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<NestedArrays> {
            JSONSchema(NestedArrays.init) {
              JSONObject {
                JSONProperty(key: "matrix") {
                  JSONArray {
                    JSONArray {
                      JSONInteger()
                    }
                  }
                  .orNull(style: .union)
                }
                .flatMapOptional()
              }
            }
          }
        }

        extension NestedArrays: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["public", "internal", "fileprivate", "package", "private"])
  func accessModifiersWithOptionalNulls(_ modifier: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(modifier) struct Weather {
        let temperature: Double?
      }
      """,
      expandedSource: """
        \(modifier) struct Weather {
          let temperature: Double?

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          \(modifier) static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .orNull(style: .type)
                }
                .flatMapOptional()
              }
            }
          }
        }

        \(modifier == "private" || modifier == "fileprivate" ? "\(modifier) " : "")extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
