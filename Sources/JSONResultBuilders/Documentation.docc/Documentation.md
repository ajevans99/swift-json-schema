# ``JSONResultBuilders``

Allows for ergonomic JSON schema generation with Swift's result builders.

## JSON Schema Builder

To get started generating JSON schemas with result builders, import the `JSONResultBuilders` target and use the ``JSONSchemaBuilder`` result builder.

```swift
@JSONSchemaBuilder var schemaRepresentation: JSONSchemaRepresentable {
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
@JSONSchemaBuilder var schemaRepresentation: JSONSchemaRepresentable {
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
@JSONSchemaBuilder var schemaRepresentation: JSONSchemaRepresentable {
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
@JSONValueBuilder var jsonValue: JSONValidRepresentable {
  JSONArray {
    JSONString("Hello, world!")
    JSONNumber(42)
  }
}
```

or use the literal extensions for JSON values.

```swift
@JSONValueBuilder var jsonValue: JSONValidRepresentable {
  [
    "Hello, world!",
    42
  ]
}
```
