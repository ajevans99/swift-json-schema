# ``JSONSchemaBuilder``

Allows for ergonomic JSON schema generation with Swift's result builders.

## Overview

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

Result builders enable composition of schemas, better readability, and validation directly into Swift types.

## Topics

- <doc:Macros>
- <doc:Validation>
- <doc:ValueBuilder>

## See Also

Check out the test sources at `Tests/JSONSchemaBuilderTests` for many more examples.
