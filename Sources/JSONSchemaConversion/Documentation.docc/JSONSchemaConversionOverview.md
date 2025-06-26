# ``JSONSchemaConversion``

## Overview

`JSONSchemaConversion` enables type-safe, schema-driven conversion from JSON to Foundation types like `UUID`, `Date`, and `URL`.

## Example

Use a custom conversion in a macro-based schema:

```swift
import JSONSchemaBuilder
import JSONSchemaConversion

@Schemable
struct MyModel {
  @SchemaOptions(.customSchema(.uuid))
  let id: UUID

  // Auto-generated schema ↴
  static var schema: some JSONSchemaComponent<MyModel> {
    JSONProperty(key: "id") {
      Conversions.uuid.schema
    }
  }
}
```

This ensures only valid UUID strings are accepted for `id` during parsing and validation.
