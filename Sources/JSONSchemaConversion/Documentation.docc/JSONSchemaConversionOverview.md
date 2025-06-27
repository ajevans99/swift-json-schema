# ``JSONSchemaConversion``

## Overview

`JSONSchemaConversion` includes some type-safe, schema-driven conversion from JSON to Foundation types like `UUID`, `Date`, and `URL`.

## Example

Use a custom conversion in a macro-based schema:

```swift
import JSONSchemaBuilder
import JSONSchemaConversion

struct Custom: Schemable {
  static var schema: some JSONSchemaComponent<String> {
    JSONString()
      .format("my-custom-format")
  }
}

@Schemable
struct MyModel {
  @SchemaOptions(.customSchema(Conversions.uuid))
  let id: UUID

  @SchemaOptions(.customSchema(Custom.self))
  let myVar: String

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent<MyModel> {
    JSONProperty(key: "id") {
      Conversions.uuid.schema
    }
    JSONProperty(key: "myVar") {
      Custom.self.schema
    }
  }
}
```

This ensures only valid UUID strings are accepted for `id` during parsing and validation and allows schema overrides for individual properties.
