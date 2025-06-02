# Macros

Automatically generate schemas from Swift types with macros.

## ``Schemable()`` Macro

The `Schemable` macro can be used to generate JSON schemas from Swift structs, classes, and enums. Just add the `@Schemable` attribute to your type and the macro will generate a `schema` property on your type.

```swift
@Schemable
struct Person {
  let firstName: String
  let lastName: String
  let age: Int
}
```

will expand to:

```swift
struct Person {
  let firstName: String
  let lastName: String
  let age: Int

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent<Person> {
    JSONSchema(Person.init) {
      JSONObject {
        JSONProperty(key: "firstName") {
          JSONString()
        }
        .required()

        JSONProperty(key: "lastName") {
          JSONString()
        }

        JSONProperty(key: "age") {
          JSONInteger()
        }
        .required()
      }
    }
  }
}

extension Person: Schemable {}
```

Access the schema property to get the JSON schema representation of the type.

There are also type specific attributes that can be used to customize the generated schema.

```swift
@Schemable
struct Person {
  @SchemaOptions(.description("The person's first name."))
  let firstName: String

  @SchemaOptions(.description("The person's last name."))
  let lastName: String

  @SchemaOptions(.description("Age in years"))
  @NumberOptions(.minimum(0), .maximum(120))
  let age: Int
}
```

which will expand to:

```swift
struct Person {
  let firstName: String
  let lastName: String?
  let age: Int

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent<Person> {
    JSONSchema(Person.init) {
      JSONObject {
        JSONProperty(key: "firstName") {
          JSONString()
          .description("The person's first name.")
        }
        .required()
        JSONProperty(key: "lastName") {
          JSONString()
          .description("The person's last name.")
        }
        JSONProperty(key: "age") {
          JSONInteger()
          .description("Age in years")
          .minimum(0)
          .maximum(120)
        }
        .required()
      }
    }
  }
}
```

``SchemaOptions(title:description:default:examples:readOnly:writeOnly:deprecated:comment:)`` may also be applied directly to the root struct or class.

### Supported Types

The following Swift primitive types are supported for macro expansion.

Swift Type | Schema (``JSONSchemaComponent``)
---|---
`String` | ``JSONString``
`Bool` | ``JSONBoolean``
`Int` | ``JSONInteger``
`Double`, `Float` | ``JSONNumber``
`Array<Element>`, `[Element]` | ``JSONArray`` \*
`Dictionary<String, Element>`, `[String: Element]` | ``JSONObject`` \*

\* Where `Element` is another primitive or ``Schemable`` type.
In Arrays, the ``JSONArray/init(items:)`` nuilder contain will the `Element` type.
In Dictionaries, the ``JSONObject/additionalProperties(_:)-5r2qu`` closure will contain the `Element` type.

```swift
@Schemable struct Book {
  let title: String
  let authors: [String]
  let yearPublished: Int
  let rating: Double

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent<Book> {
    JSONSchema(Book.init) {
      JSONObject {
        JSONProperty(key: "title") {
          JSONString()
        }
        .required()
        JSONProperty(key: "authors") {
          JSONArray {
            JSONString()
          }
        }
        .required()
        JSONProperty(key: "yearPublished") {
          JSONInteger()
        }
        .required()
        JSONProperty(key: "rating") {
          JSONNumber()
        }
        .required()
      }
    }
  }
}
```

All other types will be assumed to also conform to the ``Schemable`` protocol and will be expanded as `<TypeName>.schema`. Below is an example where `Library` has an array of `Book`.

```swift
@Schemable struct Library {
  let name: String
  let books: [Book]

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent<Library> {
    JSONSchema(Library.init) {
      JSONObject {
          JSONProperty(key: "name") {
            JSONString()
          }
          .required()
          JSONProperty(key: "books") {
            JSONArray {
              Book.schema
            }
          }
          .required()
      }
    }
  }
}
```

Computed properties are not included in generated schemas.

### Enums

The ``Schemable()`` macro can also be applied to Swift enums. The enum cases will be expanded as string literals in the schema. Only strings are supported in macro generation currently. To support other types, you must manually implement the schema.

```swift
@Schemable
enum TemperatureType: String {
  case fahrenheit
  case celsius
  case kelvin
}
```

will expand to:

```swift
enum TemperatureType: String {
  case fahrenheit
  case celsius
  case kelvin

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent<TemperatureType> {
    JSONString()
      .enumValues {
        "fahrenheit"
        "celsius"
        "kelvin"
      }
      .compactMap { string in
        switch string {
        case "fahrenheit": return TemperatureType.fahrenheit
        case "celsius": return TemperatureType.celsius
        case "kelvin": return TemperatureType.kelvin
        default: return nil
        }
      }
  }
}
```

If any of the enum cases have an associated value, the macro will instead expand using the `AnyOf` ``JSONComposition/AnyOf/init(_:)`` builder.

```swift
@Schemable
enum TemperatureKind {
  case cloudy(Double)
  case rainy(chanceOfRain: Double, amount: Double)
  case snowy
  case windy
}
```

will expand to:

```swift
enum TemperatureType {
  case cloudy(Double)
  case rainy(chanceOfRain: Double, amount: Double)
  case snowy
  case windy

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent {
    enum TemperatureKind {
      case cloudy(Double)
      case rainy(chanceOfRain: Double, amount: Double)
      case snowy
      case windy

      static var schema: some JSONSchemaComponent {
        JSONComposition.AnyOf {
          JSONObject {
            JSONProperty(key: "cloudy") {
              JSONObject {
                JSONProperty(key: "_0") {
                  JSONNumber()
                }
              }
            }
          }
          JSONObject {
            JSONProperty(key: "rainy") {
              JSONObject {
                JSONProperty(key: "chanceOfRain") {
                  JSONNumber()
                }
                JSONProperty(key: "amount") {
                  JSONNumber()
                }
              }
            }
          }
          JSONEnum {
            "snowy"
            "windy"
          }
        }
      }
    }

    extension TemperatureKind: Schemable {
    }
  }
}
```

Notice how unnamed associated values are represented as `_0`, `_1`, etc.

### Other Behaviors

#### Default values

For primitive types, if you provide a default value, it will be added to the schema as a default value. This is not supported for custom types. Notice these are `var` instead of `let` to have Swift still give us the automatic memberwise initializer for the struct.

```swift
@Schemable
struct Weather {
  var temperature: Double = 72.0
  var units: TemperatureType = .fahrenheit
  var location: String = "Detroit"

  // Auto-generated schema ↴
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
      }
    }
  }
}
```

#### Exclude from schema

Use the ``ExcludeFromSchema()`` macro on a property you wish to exclude from the generated schema. Make sure to include an initalizaer that also excludes the property.

```swift
@Schemable
struct Weather {
  let temperature: Double
  let units: TemperatureType
  let location: String

  @ExcludeFromSchema
  let secret: String

  init(temperature: Double, location: String) {
    self.temperature = temperature
    self.location = location
    self.secret = "secret"
  }
}
```
