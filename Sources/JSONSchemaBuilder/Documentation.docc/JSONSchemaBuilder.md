# ``JSONSchemaBuilder``

Build reusable JSON schemas and parse validated input into Swift types.

## Overview

Use result builders when you want explicit control over your schema, or start with <doc:Macros>
to generate a schema from a Swift model. Both approaches support schema emission, validation,
and typed parsing.

To build a schema manually, import `JSONSchemaBuilder`:

```swift
import JSONSchemaBuilder

@JSONSchemaBuilder var personSchema: some JSONSchemaComponent {
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
        .description("Age in years which must be equal to or greater than zero.")
        .minimum(0)
    }
    .required()
  }
  .title("Person")
}

let schema = personSchema.definition()
let json = try schema.jsonValue.serialized(options: .pretty)
let person = try personSchema.parseAndValidate(
  instance: #"{"firstName": "Ada", "age": 37}"#
)
```

The parsed output is `(String, String?, Int)` in property declaration order. Add `.map` to
construct your own model, as shown in <doc:Validation>. Properties are optional until marked
`.required()`; nullability is controlled separately with `.orNull()`.

## Choose your next guide

- <doc:Macros>: nested models, enums, recursive schemas, coding keys, and optional properties.
- <doc:Validation>: parsing versus validation, typed output, errors, and schema compositions.
- <doc:ConditionalValidation>: property dependencies and conditional rules.
- <doc:WrapperTypes>: transformations, type erasure, and runtime schema components.
- <doc:ValueBuilder>: construct JSON values with result builders.

For string-to-`UUID`, `URL`, and `Date` conversions, see
[`JSONSchemaConversion`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemaconversion).

## Choose a numeric output type

| Component | Swift output | Conversion |
| --- | --- | --- |
| ``JSONInteger`` | `Int` | Exact integral value within `Int` range, including tokens such as `1.0` and `1e2`. |
| ``JSONNumber`` | `Double` | Allows rounding; rejects overflow and nonzero underflow to zero. |
| ``JSONFloat`` | `Float` | Parses directly at Float precision; rejects overflow and nonzero underflow to zero. |
| ``JSONCGFloat`` | Foundation `CGFloat` | Uses the platform's native width; rejects overflow and nonzero underflow to zero. |
| ``JSONDecimal`` | Foundation `Decimal` | Exact decimal value; rejects inexact or out-of-range conversion. |

Numeric schema constraints use exact JSON values regardless of the output type. Use
`JSONNumberLiteral` bounds when Swift floating-point literals would lose precision:

```swift
import Foundation

let cent = try JSONNumberLiteral("0.01")
let amount: Decimal = try JSONDecimal()
  .minimum(0)
  .multipleOf(cent)
  .parseAndValidate(instance: "9.270")
```

The string parsing overloads preserve numeric tokens by default. `@Schemable` maps `Float`,
`CGFloat`, and `Decimal` to their matching components, including supported qualified
spellings, optional properties, and collection values. All support `@NumberOptions`.
See <doc:Macros> for recognized spellings and <doc:Validation> for conversion failures
and exact constraints.

## Reusing existing schemas with references

When you need to point at another schema fragment—either a local anchor or a remote definition—you can
stay within the builder DSL while keeping strong typing:

- ``JSONReference`` emits the standard `$ref` keyword and is ideal for definitions stored elsewhere in your document or an external file.
- ``JSONDynamicReference`` emits `$dynamicRef` for references resolved through dynamic scope, which is what the `@Schemable` macro generates for recursive properties.

Both components parse using the referenced type's schema, so results remain strongly typed.
Use `parseAndValidate(_:validationContext:)` with a context containing your external schemas
when a reference requires them.

## Pattern Properties and Additional Properties

The library supports two powerful features for object validation: pattern properties and additional properties.

### Pattern Properties

Pattern properties allow you to define validation rules for object properties whose names match a regular expression pattern. This is useful when you want to validate properties with dynamic names.

```swift
@JSONSchemaBuilder var schemaRepresentation: some JSONSchemaComponent {
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

### Property Names

The `propertyNames` modifier validates each property name using a subschema and captures the ones that match. The captured result is provided as a ``CapturedPropertyNames`` value containing the names seen, their raw strings, and an optional whitelist derived from `enum` values.

```swift
enum Emotion: String, CaseIterable { case happy, sad, angry }

@JSONSchemaBuilder var schema: some JSONSchemaComponent<((), CapturedPropertyNames<Emotion>)> {
  JSONObject()
    .propertyNames {
      JSONString()
        .enumValues { Emotion.allCases.map(\.rawValue) }
        .compactMap(Emotion.init(rawValue:))
    }
}
```

## Topics

- <doc:Macros>
- <doc:Validation>
- <doc:ValueBuilder>
- <doc:WrapperTypes>
- <doc:ConditionalValidation>

## See Also

Check out the test sources at `Tests/JSONSchemaBuilderTests` for many more examples.
