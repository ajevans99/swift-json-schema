import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

struct SchemableExpansionTests {
  let testMacros: [String: Macro.Type] = [
    "Schemable": SchemableMacro.self, "ExcludeFromSchema": ExcludeFromSchemaMacro.self,
  ]

  @Test(arguments: ["struct", "class"]) func basicTypes(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let temperature: Double
        let location: String
        let isRaining: Bool
        let windSpeed: Int
        let precipitationAmount: Double?
        let humidity: Float
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let temperature: Double
          let location: String
          let isRaining: Bool
          let windSpeed: Int
          let precipitationAmount: Double?
          let humidity: Float

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                }
                .required()
                JSONProperty(key: "location") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                }
                .required()
                JSONProperty(key: "windSpeed") {
                  JSONInteger()
                }
                .required()
                JSONProperty(key: "precipitationAmount") {
                  JSONNumber()
                }
                JSONProperty(key: "humidity") {
                  JSONNumber()
                }
                .required()
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

  @Test(arguments: ["struct", "class"]) func arraysAndDictionaries(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let temperatures: [Double]
        let temperatureByLocation: [String: Double?]
        let conditionsByLocation: [String: WeatherCondition]
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let temperatures: [Double]
          let temperatureByLocation: [String: Double?]
          let conditionsByLocation: [String: WeatherCondition]

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperatures") {
                  JSONArray {
                    JSONNumber()
                  }
                }
                .required()
                JSONProperty(key: "temperatureByLocation") {
                  JSONObject()
                  .additionalProperties {
                    JSONNumber()
                  }
                  .map(\\.1)
                }
                .required()
                JSONProperty(key: "conditionsByLocation") {
                  JSONObject()
                  .additionalProperties {
                    WeatherCondition.schema
                  }
                  .map(\\.1)
                  .map(\\.matches)
                }
                .required()
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

  @Test(arguments: ["struct", "class"]) func alternativeArraysAndDictionaries(
    declarationType: String
  ) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let temperatures: Array<Double>
        let temperatureByLocation: Dictionary<String, Double?>
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let temperatures: Array<Double>
          let temperatureByLocation: Dictionary<String, Double?>

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperatures") {
                  JSONArray {
                    JSONNumber()
                  }
                }
                .required()
                JSONProperty(key: "temperatureByLocation") {
                  JSONObject()
                  .additionalProperties {
                    JSONNumber()
                  }
                  .map(\\.1)
                }
                .required()
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

  @Test(arguments: ["struct", "class"]) func multipleBindings(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        let isRaining: Bool?, temperature: Int?, location: String
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          let isRaining: Bool?, temperature: Int?, location: String

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                }
                JSONProperty(key: "temperature") {
                  JSONInteger()
                }
                JSONProperty(key: "location") {
                  JSONString()
                }
                .required()
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

  @Test func skipComputedProperties() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        var temperature: Double {
          didSet { print("Updated temperature") }
          willSet { print("Will update temperature") }
        }

        var temperatureInCelsius: Double {
          get { (temperature - 32) * 5 / 9 }
          set { temperature = newValue * 9 / 5 + 32 }
        }

        var isCold: Bool { temperature < 50 }
      }
      """,
      expandedSource: """
        struct Weather {
          var temperature: Double {
            didSet { print("Updated temperature") }
            willSet { print("Will update temperature") }
          }

          var temperatureInCelsius: Double {
            get { (temperature - 32) * 5 / 9 }
            set { temperature = newValue * 9 / 5 + 32 }
          }

          var isCold: Bool { temperature < 50 }

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                }
                .required()
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

  @Test func defaultValue() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperature: Double = 72.0
        let units: TemperatureType = .fahrenheit
        let location: String = "Detroit"
        let isRaining: Bool = false
        let windSpeed: Int = 12
        let precipitationAmount: Double? = nil
        let humidity: Float = 0.30
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double = 72.0
          let units: TemperatureType = .fahrenheit
          let location: String = "Detroit"
          let isRaining: Bool = false
          let windSpeed: Int = 12
          let precipitationAmount: Double? = nil
          let humidity: Float = 0.30

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .default(72.0)
                }
                .required()
                JSONProperty(key: "units") {
                  TemperatureType.schema
                }
                .required()
                JSONProperty(key: "location") {
                  JSONString()
                  .default("Detroit")
                }
                .required()
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                  .default(false)
                }
                .required()
                JSONProperty(key: "windSpeed") {
                  JSONInteger()
                  .default(12)
                }
                .required()
                JSONProperty(key: "precipitationAmount") {
                  JSONNumber()
                  .default(nil)
                }
                JSONProperty(key: "humidity") {
                  JSONNumber()
                  .default(0.30)
                }
                .required()
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

  @Test func excludeFromSchema() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperature: Double
        @ExcludeFromSchema
        let units: TemperatureType
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double
          let units: TemperatureType

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                }
                .required()
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

  @Test func propertyKeyOverride() {
    assertMacroExpansion(
      """
      @Schemable
      struct Item {
        @SchemaOptions(.key("item_id"))
        let id: Int
        let name: String
      }
      """,
      expandedSource: """
        struct Item {
          @SchemaOptions(.key("item_id"))
          let id: Int
          let name: String

          static var schema: some JSONSchemaComponent<Item> {
            JSONSchema(Item.init) {
              JSONObject {
                JSONProperty(key: "item_id") {
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

        extension Item: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func typeWideKeyStrategy() {
    assertMacroExpansion(
      """
      @Schemable(keyStrategy: .snakeCase)
      struct Person {
        let firstName: String
        let lastName: String
      }
      """,
      expandedSource: """
        struct Person {
          let firstName: String
          let lastName: String

          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: Person.keyEncodingStrategy.encode("firstName")) {
                  JSONString()
                }
                .required()
                JSONProperty(key: Person.keyEncodingStrategy.encode("lastName")) {
                  JSONString()
                }
                .required()
              }
            }
          }

          static var keyEncodingStrategy: KeyEncodingStrategies {
            .snakeCase
          }
        }

        extension Person: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["public", "internal", "fileprivate", "package", "private"])
  func accessModifiers(_ modifier: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(modifier) struct Weather {
        let temperature: Double
      }
      """,
      expandedSource: """
        \(modifier) struct Weather {
          let temperature: Double

          \(modifier) static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                }
                .required()
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

  @Test(arguments: ["public", "internal", "fileprivate", "package", "private"])
  func accessModifiersWithKeyStrategy(_ modifier: String) {
    assertMacroExpansion(
      """
      @Schemable(keyStrategy: .snakeCase)
      \(modifier) struct Person {
        let firstName: String
        let lastName: String
      }
      """,
      expandedSource: """
        \(modifier) struct Person {
          let firstName: String
          let lastName: String

          \(modifier) static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: Person.keyEncodingStrategy.encode("firstName")) {
                  JSONString()
                }
                .required()
                JSONProperty(key: Person.keyEncodingStrategy.encode("lastName")) {
                  JSONString()
                }
                .required()
              }
            }
          }

          \(modifier) static var keyEncodingStrategy: KeyEncodingStrategies {
            .snakeCase
          }
        }

        \(modifier == "private" || modifier == "fileprivate" ? "\(modifier) " : "")extension Person: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func docstringSupport() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        /// The current temperature in fahrenheit
        let temperature: Double
        
        /// The city name where the weather is being reported
        let location: String
        
        /// Whether it is currently raining
        let isRaining: Bool
        
        /// The wind speed in miles per hour
        let windSpeed: Int
        
        /// The amount of precipitation in inches
        let precipitationAmount: Double?
        
        /// The relative humidity as a percentage
        let humidity: Float
      }
      """,
      expandedSource: """
        struct Weather {
          /// The current temperature in fahrenheit
          let temperature: Double
          
          /// The city name where the weather is being reported
          let location: String
          
          /// Whether it is currently raining
          let isRaining: Bool
          
          /// The wind speed in miles per hour
          let windSpeed: Int
          
          /// The amount of precipitation in inches
          let precipitationAmount: Double?
          
          /// The relative humidity as a percentage
          let humidity: Float

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .description(#\"\"\"
                  The current temperature in fahrenheit
                  \"\"\"#)
                }
                .required()
                JSONProperty(key: "location") {
                  JSONString()
                  .description(#\"\"\"
                  The city name where the weather is being reported
                  \"\"\"#)
                }
                .required()
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                  .description(#\"\"\"
                  Whether it is currently raining
                  \"\"\"#)
                }
                .required()
                JSONProperty(key: "windSpeed") {
                  JSONInteger()
                  .description(#\"\"\"
                  The wind speed in miles per hour
                  \"\"\"#)
                }
                .required()
                JSONProperty(key: "precipitationAmount") {
                  JSONNumber()
                  .description(#\"\"\"
                  The amount of precipitation in inches
                  \"\"\"#)
                }
                JSONProperty(key: "humidity") {
                  JSONNumber()
                  .description(#\"\"\"
                  The relative humidity as a percentage
                  \"\"\"#)
                }
                .required()
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

  @Test func docstringWithSchemaOptions() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        /// The current temperature in fahrenheit
        @SchemaOptions(.description("Temperature in degrees Fahrenheit"))
        let temperature: Double
        
        /// The city name where the weather is being reported
        let location: String
      }
      """,
      expandedSource: """
        struct Weather {
          /// The current temperature in fahrenheit
          @SchemaOptions(.description("Temperature in degrees Fahrenheit"))
          let temperature: Double
          
          /// The city name where the weather is being reported
          let location: String

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .description("Temperature in degrees Fahrenheit")
                }
                .required()
                JSONProperty(key: "location") {
                  JSONString()
                  .description(#\"\"\"
                  The city name where the weather is being reported
                  \"\"\"#)
                }
                .required()
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

  @Test func blockDocstringSupport() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        /**
         * The current temperature in fahrenheit.
         * This value should be between -100 and 150.
         */
        let temperature: Double
        
        /**
         * The city name where the weather is being reported.
         * Must be a valid city name.
         */
        let location: String
      }
      """,
      expandedSource: """
        struct Weather {
          /**
           * The current temperature in fahrenheit.
           * This value should be between -100 and 150.
           */
          let temperature: Double
          
          /**
           * The city name where the weather is being reported.
           * Must be a valid city name.
           */
          let location: String

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                  .description(#\"\"\"
                  The current temperature in fahrenheit.
                  This value should be between -100 and 150.
                  \"\"\"#)
                }
                .required()
                JSONProperty(key: "location") {
                  JSONString()
                  .description(#\"\"\"
                  The city name where the weather is being reported.
                  Must be a valid city name.
                  \"\"\"#)
                }
                .required()
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

  @Test func complexDocstringSupport() {
    assertMacroExpansion(
      """
      @Schemable
      struct ComplexDocstring {
        /// This is a complex docstring with **bold** and *italic* text.
        /// It spans multiple lines and includes:
        /// - Bullet points
        /// - More bullet points
        /// 
        /// It also has a code block:
        /// ```swift
        /// let example = "code"
        /// ```
        /// 
        /// And some `inline code` as well.
        let complexProperty: String
      }
      """,
      expandedSource: """
        struct ComplexDocstring {
          /// This is a complex docstring with **bold** and *italic* text.
          /// It spans multiple lines and includes:
          /// - Bullet points
          /// - More bullet points
          /// 
          /// It also has a code block:
          /// ```swift
          /// let example = "code"
          /// ```
          /// 
          /// And some `inline code` as well.
          let complexProperty: String

          static var schema: some JSONSchemaComponent<ComplexDocstring> {
            JSONSchema(ComplexDocstring.init) {
              JSONObject {
                JSONProperty(key: "complexProperty") {
                  JSONString()
                  .description(#\"\"\"
                  This is a complex docstring with **bold** and *italic* text.
                  It spans multiple lines and includes:
                  - Bullet points
                  - More bullet points\n
                  It also has a code block:
                  ```swift
                  let example = "code"
                  ```\n
                  And some `inline code` as well.
                  \"\"\"#)
                }
                .required()
              }
            }
          }
        }

        extension ComplexDocstring: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func dictionaryWithEnumKeys(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      enum TestEmotion: String {
        case happy
        case sad
      }

      @Schemable
      struct TestEmotionValue {
        let value: Int
      }

      @Schemable
      \(declarationType) TestPerson {
        let emotions: [TestEmotion: TestEmotionValue]
        let analysisNotes: String
      }
      """,
      expandedSource: """
        enum TestEmotion: String {
          case happy
          case sad

          static var schema: some JSONSchemaComponent<TestEmotion> {
            JSONString()
              .enumValues {
                "happy"
                "sad"
              }
              .compactMap {
                switch $0 {
                case "happy":
                  return Self.happy
                case "sad":
                  return Self.sad
                default:
                  return nil
                }
              }
          }
        }

        struct TestEmotionValue {
          let value: Int

          static var schema: some JSONSchemaComponent<TestEmotionValue> {
            JSONSchema(TestEmotionValue.init) {
              JSONObject {
                JSONProperty(key: "value") {
                  JSONInteger()
                }
                .required()
              }
            }
          }
        }

        \(declarationType) TestPerson {
          let emotions: [TestEmotion: TestEmotionValue]
          let analysisNotes: String

          static var schema: some JSONSchemaComponent<TestPerson> {
            JSONSchema(TestPerson.init) {
              JSONObject {
                JSONProperty(key: "emotions") {
                  JSONObject()
                  .additionalProperties {
                    TestEmotionValue.schema
                  }
                  .map(\\.1)
                  .propertyNames {
                    TestEmotion.schema
                  }
                }
                .required()
                JSONProperty(key: "analysisNotes") {
                  JSONString()
                }
                .required()
              }
            }
          }
        }

        extension TestEmotion: Schemable {
        }
        extension TestEmotionValue: Schemable {
        }
        extension TestPerson: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
