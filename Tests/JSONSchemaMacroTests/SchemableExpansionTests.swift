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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
                  .orNull(style: .type)
                }
                .flatMapOptional()
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
                  .map(\\.matches)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

  @Test func jsonValueProperties() {
    assertMacroExpansion(
      """
      @Schemable
      struct Update {
        let path: String
        let value: JSONValue
        let meta: [String: JSONValue]
      }
      """,
      expandedSource: """
        struct Update {
          let path: String
          let value: JSONValue
          let meta: [String: JSONValue]

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Update> {
            JSONSchema(Update.init) {
              JSONObject {
                JSONProperty(key: "path") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "value") {
                  JSONValue.schema
                }
                .required()
                JSONProperty(key: "meta") {
                  JSONObject()
                  .additionalProperties {
                    JSONValue.schema
                  }
                  .map(\\.1)
                  .map(\\.matches)
                }
                .required()
              }
            }
          }
        }

        extension Update: Schemable {
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "isRaining") {
                  JSONBoolean()
                  .orNull(style: .type)
                }
                .flatMapOptional()
                JSONProperty(key: "temperature") {
                  JSONInteger()
                  .orNull(style: .type)
                }
                .flatMapOptional()
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
                  .orNull(style: .type)
                }
                .flatMapOptional()
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
                  .orNull(style: .type)
                }
                .flatMapOptional()
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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

  @Test func dictionaryWithCustomKeySchema() {
    assertMacroExpansion(
      """
      @Schemable
      struct TestPerson {
        let emotions: [TestEmotion: Int]
        let analysisNotes: String
      }
      """,
      expandedSource: """
        struct TestPerson {
          let emotions: [TestEmotion: Int]
          let analysisNotes: String

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<TestPerson> {
            JSONSchema(TestPerson.init) {
              JSONObject {
                JSONProperty(key: "emotions") {
                  JSONObject()
                  .propertyNames {
                    TestEmotion.schema
                  }
                  .additionalProperties {
                    JSONInteger()
                  }
                  .map { value in
                    let (_, capturedNames) = value.0
                    let additionalProperties = value.1
                    return Dictionary(
                      uniqueKeysWithValues: zip(capturedNames.seen, capturedNames.raw)
                        .compactMap { parsedKey, rawKey in
                          additionalProperties.matches[rawKey].map { parsedValue in
                            (parsedKey, parsedValue)
                          }
                        }
                    )
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

        extension TestPerson: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func dictionaryWithStringKeys() {
    assertMacroExpansion(
      """
      @Schemable
      struct SimpleStringIntDict {
        let emotions: [String: Int]
      }
      """,
      expandedSource: """
        struct SimpleStringIntDict {
          let emotions: [String: Int]

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<SimpleStringIntDict> {
            JSONSchema(SimpleStringIntDict.init) {
              JSONObject {
                JSONProperty(key: "emotions") {
                  JSONObject()
                  .additionalProperties {
                    JSONInteger()
                  }
                  .map(\\.1)
                  .map(\\.matches)
                }
                .required()
              }
            }
          }
        }

        extension SimpleStringIntDict: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func extensionDefinedType(declarationType: String) {
    assertMacroExpansion(
      """
      public extension Weather {
        @Schemable
        \(declarationType) Forecast {
          let temperature: Double
          let humidity: Int
        }
      }
      """,
      expandedSource: """
        public extension Weather {
          \(declarationType) Forecast {
            let temperature: Double
            let humidity: Int

            @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
            public static var schema: some JSONSchemaComponent<Forecast> {
              JSONSchema(Forecast.init) {
                JSONObject {
                  JSONProperty(key: "temperature") {
                    JSONNumber()
                  }
                  .required()
                  JSONProperty(key: "humidity") {
                    JSONInteger()
                  }
                  .required()
                }
              }
            }
          }
        }

        extension Weather.Forecast: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func extensionDefinedTypeTwoLevelsDeep(
    declarationType: String
  ) {
    assertMacroExpansion(
      """
      public extension Weather {
        \(declarationType) Forecast {
          @Schemable
          \(declarationType) Hourly {
            let temperature: Double
            let windSpeed: Int
          }
        }
      }
      """,
      expandedSource: """
        public extension Weather {
          \(declarationType) Forecast {
            \(declarationType) Hourly {
              let temperature: Double
              let windSpeed: Int

              @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
              public static var schema: some JSONSchemaComponent<Hourly> {
                JSONSchema(Hourly.init) {
                  JSONObject {
                    JSONProperty(key: "temperature") {
                      JSONNumber()
                    }
                    .required()
                    JSONProperty(key: "windSpeed") {
                      JSONInteger()
                    }
                    .required()
                  }
                }
              }
            }
          }
        }

        extension Weather.Forecast.Hourly: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func extensionDefinedTypeThreeLevelsDeep(
    declarationType: String
  ) {
    assertMacroExpansion(
      """
      public extension Weather {
        \(declarationType) Forecast {
          \(declarationType) Hourly {
            @Schemable
            \(declarationType) Detailed {
              let temperature: Double
            }
          }
        }
      }
      """,
      expandedSource: """
        public extension Weather {
          \(declarationType) Forecast {
            \(declarationType) Hourly {
              \(declarationType) Detailed {
                let temperature: Double

                @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
                public static var schema: some JSONSchemaComponent<Detailed> {
                  JSONSchema(Detailed.init) {
                    JSONObject {
                      JSONProperty(key: "temperature") {
                        JSONNumber()
                      }
                      .required()
                    }
                  }
                }
              }
            }
          }
        }

        extension Weather.Forecast.Hourly.Detailed: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test func extensionDefinedTypeWithMixedDeclarationTypes() {
    assertMacroExpansion(
      """
      public extension Weather {
        class Forecast {
          @Schemable
          enum Status {
            case sunny
            case cloudy
          }
        }
      }
      """,
      expandedSource: """
        public extension Weather {
          class Forecast {
            enum Status {
              case sunny
              case cloudy

              @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
              public static var schema: some JSONSchemaComponent<Status> {
                JSONString()
                  .enumValues {
                    "sunny"
                    "cloudy"
                  }
                  .compactMap {
                    switch $0 {
                    case "sunny":
                      return Self.sunny
                    case "cloudy":
                      return Self.cloudy
                    default:
                      return nil
                    }
                  }
              }
            }
          }
        }

        extension Weather.Forecast.Status: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func directlyNestedType(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Weather {
        @Schemable
        \(declarationType) Forecast {
          let temperature: Double
          let humidity: Int
        }
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          \(declarationType) Forecast {
            let temperature: Double
            let humidity: Int

            @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
            static var schema: some JSONSchemaComponent<Forecast> {
              JSONSchema(Forecast.init) {
                JSONObject {
                  JSONProperty(key: "temperature") {
                    JSONNumber()
                  }
                  .required()
                  JSONProperty(key: "humidity") {
                    JSONInteger()
                  }
                  .required()
                }
              }
            }
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
              }
            }
          }
        }

        extension Weather.Forecast: Schemable {
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func directlyNestedTypeTwoLevelsDeep(
    declarationType: String
  ) {
    assertMacroExpansion(
      """
      \(declarationType) Weather {
        \(declarationType) Forecast {
          @Schemable
          \(declarationType) Hourly {
            let temperature: Double
          }
        }
      }
      """,
      expandedSource: """
        \(declarationType) Weather {
          \(declarationType) Forecast {
            \(declarationType) Hourly {
              let temperature: Double

              @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
              static var schema: some JSONSchemaComponent<Hourly> {
                JSONSchema(Hourly.init) {
                  JSONObject {
                    JSONProperty(key: "temperature") {
                      JSONNumber()
                    }
                    .required()
                  }
                }
              }
            }
          }
        }

        extension Weather.Forecast.Hourly: Schemable {
        }
        """,
      macros: testMacros
    )
  }

  @Test(arguments: ["struct", "class"]) func customCodingKeys(declarationType: String) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Person {
        let firstName: String
        let lastName: String
        let emailAddress: String

        enum CodingKeys: String, CodingKey {
          case firstName = "first_name"
          case lastName = "last_name"
          case emailAddress = "email"
        }
      }
      """,
      expandedSource: """
        \(declarationType) Person {
          let firstName: String
          let lastName: String
          let emailAddress: String

          enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case emailAddress = "email"
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "first_name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "last_name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "email") {
                  JSONString()
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

  @Test(arguments: ["struct", "class"]) func customCodingKeysWithSchemaOptionsOverride(
    declarationType: String
  ) {
    assertMacroExpansion(
      """
      @Schemable
      \(declarationType) Person {
        let firstName: String
        @SchemaOptions(.key("surname"))
        let lastName: String

        enum CodingKeys: String, CodingKey {
          case firstName = "first_name"
          case lastName = "last_name"
        }
      }
      """,
      expandedSource: """
        \(declarationType) Person {
          let firstName: String
          @SchemaOptions(.key("surname"))
          let lastName: String

          enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "first_name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "surname") {
                  JSONString()
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

  @Test(arguments: ["struct", "class"]) func customCodingKeysWithKeyStrategy(
    declarationType: String
  ) {
    assertMacroExpansion(
      """
      @Schemable(keyStrategy: .snakeCase)
      \(declarationType) Person {
        let firstName: String
        let middleName: String
        let lastName: String

        enum CodingKeys: String, CodingKey {
          case firstName = "given_name"
          case middleName
          case lastName = "family_name"
        }
      }
      """,
      expandedSource: """
        \(declarationType) Person {
          let firstName: String
          let middleName: String
          let lastName: String

          enum CodingKeys: String, CodingKey {
            case firstName = "given_name"
            case middleName
            case lastName = "family_name"
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
          static var schema: some JSONSchemaComponent<Person> {
            JSONSchema(Person.init) {
              JSONObject {
                JSONProperty(key: "given_name") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "middleName") {
                  JSONString()
                }
                .required()
                JSONProperty(key: "family_name") {
                  JSONString()
                }
                .required()
              }
            }
          }

          @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
}
