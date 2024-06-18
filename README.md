# Swift JSON Schema

[![CI](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml)

## Schema Generation

Swift JSON Schema enables type-safe JSON schema generation directly in Swift.

Here's a simple example of a person schema.

```json
{
  "$id": "https://example.com/person.schema.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Person",
  "type": "object",
  "properties": {
    "firstName": {
      "type": "string",
      "description": "The person's first name."
    },
    "lastName": {
      "type": "string",
      "description": "The person's last name."
    },
    "age": {
      "description": "Age in years which must be equal to or greater than zero.",
      "type": "integer",
      "minimum": 0
    }
  }
}
```

`RootSchema` and `Schema` types are used to define the schema structure in Swift. The `RootSchema` type represents the root of the schema document, and the `Schema` type represents a JSON schema object.

```swift
let schema = RootSchema(
  id: "https://example.com/person.schema.json",
  schema: "https://json-schema.org/draft/2020-12/schema",
  subschema: .object(
    .annotations(title: "Person"),
    .options(
      properties: [
        "firstName": .string(
          .annotations(description: "The person's first name.")
        ),
        "lastName": .string(
          .annotations(description: "The person's last name.")
        ),
        "age": .integer(
          .annotations(description: "Age in years which must be equal to or greater than zero."),
          .options(minimum: 0)
        )
      ]
    )
  )
)
```

### Codable

Both `Schema` and `RootSchema` conform to `Codable` for easy serialization

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let data = try encoder.encode(self)
let string = String(decoding: data, as: UTF8.self)
```

or deserialization

```swift
let decoder = JSONDecoder()
let data = Data(json.utf8)
let schema = try decoder.decode(Schema.self, from: data)
```

### Result Builers

Import the `JSONResultBuilders` target and improve schema generation ergonomics with Swift's result builders.

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

schemaRepresentation.schema // Same `Schema` type as above for quick serialization
```

## Next Steps

This library is in active development. If you have any feedback or suggestions, please open an issue or pull request.

Goals for future releases include:
- [ ] Support enums in result builders
- [ ] Root schema in result builders
- [ ] Validate JSON instances against schemas
- [ ] **Macros** for struct-based schema generation
- [ ] Parse JSON instances into Swift types and functions

### Detailed Macro _Goal_ Example

Add a `@Schemable` attribute to a struct to generate a schema for the struct.

```swift
// Future macro-based schema generation goal example
@Schemable
struct Person: Codable {
  @SchemaOptions(description: "The person's first name.")
  let firstName: String
  
  @SchemaOptions(description: "The person's last name.")
  let lastName: String
  
  @SchemaOptions(description: "Age in years.", minimum: 0)
  let age: Int
}
```

The `@Schemable` attribute would generate a schema for the `Person` struct.

```swift
/// Generated property on `Person` struct by `@Schemable` attribute
@JSONSchemaBuilder static var schemaRepresentation: JSONSchemaRepresentable {
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

Validation and parsing would be handled by the library.

```swift
let person = """
{
  "firstName": "John",
  "lastName": "Doe",
  "age": 30
}
"""

let validation = try Person.validate(person)
#expect(validation == .success)
let instance = try Person.parse(person)
#expect(instance == Person(firstName: "John", lastName: "Doe", age: 30))
```

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
