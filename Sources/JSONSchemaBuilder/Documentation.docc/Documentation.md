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

## ``Schemable`` Macro

The `Schemable` macro can be used to generate JSON schemas from Swift types. Just add the `@Schemable` attribute to your type and the macro will generate a `schema` property on your type.

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
  }
}

extension Person: Schemable {}
```

Access the schema property to get the JSON schema representation of the type.

There are also type specific attributes that can be used to customize the generated schema.

```swift
@Schemable
struct Person {
  @JSONProperty(description: "The person's first name.")
  let firstName: String

  @JSONProperty(description: "The person's last name.")
  let lastName: String

  @JSONProperty(description: "Age in years")
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
  }
}
```
