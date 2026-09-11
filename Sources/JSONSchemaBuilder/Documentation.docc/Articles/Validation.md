# Validation

Use result builders to generate parsed type-safe, schema validated results.

## Overview

To demonstrate validation, lets build an item in a virtual shopping cart. The item has an ID, name, price, and whether or not it is in-stock. Let's define the JSON schema for each property with result builders.

```swift
let identifierSchema = JSONString()
  .pattern("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
  .description("Unique identifier for the product")

let nameSchema = JSONString()
  .minLength(1)
  .description("Name of the product")

let priceSchema = JSONNumber()
  .multipleOf(0.01)
  .description("Price of the product in USD")

let inStockSchema = JSONBoolean()
  .description("Availablility status of the product")
```

To validate, pass an instance of `JSONValue` to the ``JSONSchemaComponent/validate(_:)``. The result is a ``Validated`` enum which will either by ``Validated/valid(_:)`` if the instance meets the schema constraints, or else ``Validated/invalid(_:)``.

```swift
let id = identifierSchema.validate(.string("E621E1F8-C36C-495A-93FC-0C247A3E6E5F")) // Parsed<String, String>
let name = nameSchema.validate(.string("iPad")) // Parsed<String, String>
let price = priceSchema.validate(.number(199.99)) // Parsed<Double, String>
let inStock = inStockSchema.validate(.boolean(true)) // Parsed<Bool, String>
```

Notice that in the valid case, the first generic is a Swift primitives, not a `JSONValue` anymore. Of course, your instance is more likely to be a JSON string format.

```json
{
  "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
  "name": "iPad",
  "price": 199.99,
  "inStock": true
}
```

We can take our properties from before and create a ``JSONObject`` schema for the item.

```swift
let itemSchema = JSONObject {
  JSONProperty(key: "id", value: identifierSchema)
  JSONProperty(key: "name", value: nameSchema)
  JSONProperty(key: "price", value: priceSchema)
  JSONProperty(key: "inStock", value: inStockSchema)
}
```

And now we are ready to validate.

```swift
let itemValidationResult = itemSchema.validate(itemInstance) // Parsed<(String?, String?, Double?, Bool?), String>
switch itemValidationResult {
case .valid(let value):
  print(value)
case .invalid(let array):
  print("Errors: \(array.joined(separator: ", "))")
}
```

`value` in the above is a tuple that lines up with the properties in order, in our case: `(String?, String?, Double?, Bool?)`. To avoid the optional, we can mark properties as ``JSONProperty/required()`` in the schema. If the property is missing in the instance (or `null`), we will receive an appropriate validation error.

Let's also create a struct to represent the item in our Swift code.

```swift
struct Item {
  let id: String
  let name: String
  let price: Double
  let inStock: Bool
}
```

Putting everything together and adding a mapping function to convert the validated tuple to an `Item` instance, we get the following:

```swift
let newItemSchema = JSONObject {
  JSONProperty(key: "id") {
    JSONString() // 1
      .pattern("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
      .description("Unique identifier for the product")
  }
  .required() // 2

  JSONProperty(key: "name") {
    JSONString()
      .minLength(1)
      .description("Name of the product")
  }
  .required()

  JSONProperty(key: "price") {
    JSONNumber()
      .multipleOf(0.01)
      .description("Price of the product in USD")
  }
  .required()

  JSONProperty(key: "inStock") {
    JSONBoolean()
      .description("Availablility status of the product")
  }
  .required()
}
.map(Item.init) // 3

let item = newItemSchema.validate(itemInstance) // Parsed<Item, String>
```

1. Moved the schema definition inside the property builder with ``JSONProperty/init(key:builder:)``
2. Marked the property as required with ``JSONProperty/required()``
3. Added a mapping function to convert the validated tuple to an `Item` instance with ``JSONSchemaComponent/map(_:)`` 
> Note: `.map(Item.init)` is a shorthand for `.map { Item(id: $0.0, name: $0.1, price: $0.2, inStock: $0.3) }`

The library also provides ``JSONSchema/init(_:component:)`` to make it easy to transform the validated result to a custom type, instead of using the `map`.

Macros will generate the schema for you, so you don't have to write it by hand. <doc:Macros>

## Composition parsing

`parse(_:)` converts JSON into Swift values. Primitive parsers check the input type, but do not
independently enforce every schema keyword. Use `parseAndValidate(_:validationContext:)` to require
both a successful conversion and validity against the complete schema.

Compositions also validate each branch's schema before running its parser. Constraints such as
`minLength`, `pattern`, `const`, nested object requirements, and boolean schemas participate in
branch selection, even when multiple branches produce the same Swift type:

```swift
let text = JSONComposition.OneOf(into: String.self) {
  JSONString().minLength(5)
  JSONString().maxLength(3)
}
let value = try text.parseAndValidate(.string("hi")) // "hi", from the second branch
```

- `AnyOf` returns the first schema-valid branch whose parser succeeds, in declaration order.
- `OneOf` requires exactly one branch that is both schema-valid and successfully parsed.
- `AllOf` requires every branch to validate and parse successfully, and returns the first branch's
  output. It does not merge object fields or Swift outputs.
- `Not` rejects a value when its branch both validates and parses successfully.

Mappings still transform the selected output. A custom parser or `compactMap` can reject an
otherwise schema-valid branch. For example, direct `OneOf.parse` can have one successful parser
even though two JSON schemas match; `parseAndValidate` still rejects that instance as ambiguous.
Similarly, a custom parsing failure inside `Not` does not override the complete schema's verdict.
Schema failures are reported as nested `ParseIssue.runtimeValidationIssue` values, retaining
keyword and instance locations.

### Validation context and projections

`parseAndValidate` evaluates the complete schema before parsing and reuses its branch results.
Nested properties, array items, nullable unions, and typed references retain the caller's format
validators, remote schemas, enclosing definitions, identifiers, vocabulary, and dynamic-reference
scope. Direct composition, object, and array parsing uses a default draft 2020-12 context; pass
`validationContext` to `parseAndValidate` when external schemas or custom formats are needed.

Custom components, `flatMap`, and type-erased components can parse a shape different from their
emitted `schemaValue`, such as an object projection of `allOf`. Unmatched, self-contained branches
are evaluated separately with the caller's dialect and format validators, while the original full
schema remains authoritative. This does not add field merging to `AllOf`.

A projected branch containing `$ref` or `$dynamicRef`, or a projection under a custom vocabulary,
requires a matching position and branch schema in the original validation tree. Otherwise parsing
reports that branch validation is unavailable, rather than guessing a reference scope or using
default validation options. Keep the parsing and emitted schema structures aligned for referenced
projections, or inline their references before projecting.

This also applies when a projection hides a branch's own custom vocabulary. Typed reference parsers
only reuse evaluations belonging to their emitted reference schema; an unmatched reference cannot
borrow another target's results or independently validate its nested compositions.
