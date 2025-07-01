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

## Pattern Properties and Additional Properties

The library supports two powerful features for object validation: pattern properties and additional properties.

### Pattern Properties

Pattern properties allow you to define validation rules for object properties whose names match a regular expression pattern. This is useful when you want to validate properties with dynamic names.

```swift
@JSONSchemaBuilder var schemaRepresentation: JSONSchemaComponent {
  JSONObject {
    JSONProperty(key: "name") {
      JSONString()
    }
  }
  .patternProperties {
    JSONProperty(key: "^[0-9]+$") {
      JSONNumber()
        .minimum(0)
    }
  }
}
```

This schema will validate that:
- The `name` property is a string
- Any property whose name consists of only digits must be a number greater than or equal to 0

### Additional Properties

Additional properties allow you to define validation rules for any properties not explicitly defined in the schema. You can either:
1. Allow any additional properties (default behavior)
2. Disallow additional properties by setting `false`
3. Define a schema that all additional properties must conform to

```swift
// Allow any additional properties (default)
let schema1 = JSONObject {
  JSONProperty(key: "name") {
    JSONString()
  }
}

// Disallow additional properties
let schema2 = JSONObject {
  JSONProperty(key: "name") {
    JSONString()
  }
}
.additionalProperties {
  false
}

// Define schema for additional properties
let schema3 = JSONObject {
  JSONProperty(key: "name") {
    JSONString()
  }
}
.additionalProperties {
  JSONNumber()
    .minimum(0)
}
```

The third example will validate that:
- The `name` property is a string
- Any additional properties must be numbers greater than or equal to 0

## Topics

- <doc:Macros>
- <doc:Validation>
- <doc:ValueBuilder>
- <doc:WrapperTypes>
- <doc:ConditionalValidation>

## See Also

Check out the test sources at `Tests/JSONSchemaBuilderTests` for many more examples.
