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
let id = identifierSchema.validate(.string("E621E1F8-C36C-495A-93FC-0C247A3E6E5F")) // Validated<String, String>
let name = nameSchema.validate(.string("iPad")) // Validated<String, String>
let price = priceSchema.validate(.number(199.99)) // Validated<Double, String>
let inStock = inStockSchema.validate(.boolean(true)) // Validated<Bool, String>
```

Notice that in the valid case, the first generic is a Swift primatives, not a `JSONValue` anymore. Of course, your instance is more likely to be a JSON string format.

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
let itemValidationResult = itemSchema.validate(itemInstance) // Validated<(String?, String?, Double?, Bool?), String>
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

let item = newItemSchema.validate(itemInstance) // Validated<Item, String>
```

1. Moved the schema definition inside the property builder with ``JSONProperty/init(key:builder:)``
2. Marked the property as required with ``JSONProperty/required()``
3. Added a mapping function to convert the validated tuple to an `Item` instance with ``JSONSchemaComponent/map(_:)`` 
> Note: `.map(Item.init)` is a shorthand for `.map { Item(id: $0.0, name: $0.1, price: $0.2, inStock: $0.3) }`

The library also provides ``JSONSchema/init(_:component:)`` to make it easy to transform the validated result to a custom type, instead of using the `map`.

Macros will generate the schema for you, so you don't have to write it by hand. <doc:Macros>
