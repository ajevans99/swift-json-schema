# ``JSONSchemaBuilder``

Allows for ergonomic JSON schema generation with Swift's result builders.

## JSON Schema Builder

To get started generating JSON schemas with result builders, import the `JSONSchemaBuilder` target and use the ``JSONSchemaBuilder`` result builder.

```swift
@JSONSchemaBuilder var schemaRepresentation: JSONSchemaComponent {
  JSONObject {
    JSONProperty(key: "firstName") {
      JSONString()
        .description("The person's first name.")
    }

    JSONProperty(key: "lastName") {
      JSONString()
        .description("The person's last name.")
    }

    JSONProperty(key: "age") {
      JSONInteger()
        .description("Age in years which must be equal to or greater than zero.")
        .minimum(0)
    }
  }
  .title("Person")
}
```

Result builders make composition of schemas easier and more powerful. For example, you can use the `if` statement to conditionally include properties in a schema.

```swift
@JSONSchemaBuilder var schemaRepresentation: JSONSchemaComponent {
  JSONObject {
    JSONProperty(key: "firstName") {
      JSONString()
        .description("The person's first name.")
    }

    JSONProperty(key: "lastName") {
      JSONString()
        .description("The person's last name.")
    }

    if shouldIncludeAge {
      JSONProperty(key: "age") {
        JSONInteger()
          .description("Age in years which must be equal to or greater than zero.")
          .minimum(0)
      }
    }
  }
  .title("Person")
}
```

or use the `array` statement to include multiple properties.

```swift
@JSONSchemaBuilder var schemaRepresentation: JSONSchemaComponent {
  JSONObject {
    for item in items {
      JSONProperty(key: item.key) {
        JSONString()
          .description(item.description)
      }
    }
  }
  .title("Person")
}
```

## JSON Value Builder

You can also use the ``JSONValueBuilder`` result builder to create JSON values.

```swift
@JSONValueBuilder var jsonValue: JSONValueRepresentable {
  JSONArray {
    JSONString("Hello, world!")
    JSONNumber(42)
  }
}
```

or use the literal extensions for JSON values.

```swift
@JSONValueBuilder var jsonValue: JSONValueRepresentable {
  [
    "Hello, world!",
    42
  ]
}
```

## ``Schemable()`` Macro

The `Schemable` macro can be used to generate JSON schemas from Swift structs and classes. Just add the `@Schemable` attribute to your type and the macro will generate a `schema` property on your type.

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
  static var schema: JSONSchemaComponent {
    JSONObject {
      JSONProperty(key: "firstName") {
        JSONString()
      }

      JSONProperty(key: "lastName") {
        JSONString()
      }

      JSONProperty(key: "age") {
        JSONInteger()
      }
    }
    .required(["firstName", "lastName", "age"])
  }
}

extension Person: Schemable {}
```

Access the schema property to get the JSON schema representation of the type.

There are also type specific attributes that can be used to customize the generated schema.

```swift
@Schemable
struct Person {
  @SchemaOptions(description: "The person's first name.")
  let firstName: String

  @SchemaOptions(description: "The person's last name.")
  let lastName: String

  @SchemaOptions(description: "Age in years")
  @JSONInteger(minimum: 0, maximum: 120)
  let age: Int
}
```

which will expand to:

```swift
struct Person {
  let firstName: String
  let lastName: String
  let age: Int

  // Auto-generated schema ↴
  static var schema: JSONSchemaComponent {
    JSONObject {
      JSONProperty(key: "firstName") {
        JSONString()
          .description("The person's first name.")
      }

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
    }
    .required(["firstName", "lastName", "age"])
  }
}
```

``SchemaOptions(title:description:default:examples:readOnly:writeOnly:deprecated:comment:)`` may also be applied directly to the root struct or class.

### Supported Types

The following Swift primative types are supported for macro expansion.

Swift Type | Schema (``JSONSchemaComponent``)
---|---
`String` | ``JSONString``
`Bool` | ``JSONBoolean``
`Int` | ``JSONInteger``
`Double`, `Float` | ``JSONNumber``
`Array<Element>`, `[Element]` | ``JSONArray`` \*
`Dictionary<String, Element>`, `[String: Element]` | ``JSONObject`` \*

\* Where `Element` is another primative or ``Schemable`` type.
In Arrays, the ``JSONArray/items(_:)-3dfky`` closure contain will the `Element` type.
In Dictionaries, the ``JSONObject/additionalProperties(_:)-2z9zm`` closure will contain the `Element` type.

```swift
@Schemable struct Book {
  let title: String
  let authors: [String]
  let yearPublished: Int
  let rating: Double

  // Auto-generated schema ↴
  static var schema: JSONSchemaComponent {
    JSONObject {
      JSONProperty(key: "name") {
        JSONString()
      }
      JSONProperty(key: "books") {
        JSONArray()
          .items {
            Book.schema
          }
      }
    }
    .required(["name", "books"])
  }
}
```

All other types will be assumed to also conform to the ``Schemable`` protocol and will be expanded as `<TypeName>.schema`. Below is an example where `Library` has an array of `Book`.

```swift
@Schemable struct Library {
  let name: String
  var books: [Book] = []

  // Auto-generated schema ↴
  static var schema: JSONSchemaComponent {
    JSONObject {
      JSONProperty(key: "name") {
        JSONString()
      }
      JSONProperty(key: "books") {
        JSONArray()
          .items {
            Book.schema
          }
        }
      }
    .required(["name", "books"])
  }
}
```

Computed properties are not included in generated schemas.

### Enums

The ``Schemable()`` macro can also be applied to Swift enums. The enum cases will be expanded as string literals in the schema.

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
  static var schema: JSONSchemaComponent {
    JSONEnum {
      "fahrenheit"
      "celsius"
      "kelvin"
    }
  }
}
```

If any of the enum cases have an associated value, the macro will instead expand using the ``JSONComposition/AnyOf/init(_:)`` builder.

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
  static var schema: JSONSchemaComponent {
    enum TemperatureKind {
      case cloudy(Double)
      case rainy(chanceOfRain: Double, amount: Double)
      case snowy
      case windy

      static var schema: JSONSchemaComponent {
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

#### Required properties

Non-optional properties are added as required properties in the macro generated schema. You can override this behavior by using ``ObjectOptions(required:propertyNames:minProperties:maxProperties:)`` on the type.

```swift
@Schemable
@ObjectOptions(
  requirements: []
)
struct Weather {
  let cityName: String

  static var schema: JSONSchemaComponent {
    JSONObject {
      JSONProperty(key: "cityName") {
        JSONString()
      }
    }
    .requirements([])
  }
}
```

#### Default values

For primative types, if you provide a default value, it will be added to the schema as a default value. This is not supported for custom types.

```swift
@Schemable
struct Weather {
  let temperature: Double = 72.0
  let units: TemperatureType = .fahrenheit
  let location: String = "Detroit"

  // Auto-generated schema ↴
  static var schema: JSONSchemaComponent {
    JSONObject {
      JSONProperty(key: "temperature") {
        JSONNumber()
          .default(72.0)
      }
      JSONProperty(key: "units") {
        TemperatureType.schema
      }
      JSONProperty(key: "location") {
        JSONString()
          .default("Detroit")
      }
    }
    .required(["temperature", "units", "location"])
  }
}
```
