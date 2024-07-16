# Swift JSON Schema

[![CI](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml)

JSON Schema is a powerful tool for defining the structure of JSON documents. Swift JSON Schema aims to make it easier to generate JSON schema documents directly in Swift.

The [OpenAI Functions Tools API](https://platform.openai.com/docs/api-reference/assistants/createAssistant#assistants-createassistant-tools) is an example of a service that uses JSON schema to define the structure of API requests and responses.

* [Schema Generation](#schema-generation)
* [Installation](#installation)
* [Documentation](#documentation)
* [Next Steps](#next-steps)
* [License](#license)

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

Let's create this schema directly in Swift. `RootSchema` and `Schema` types are used to define the schema structure. The `RootSchema` type represents the root of the schema document, and the `Schema` type represents a JSON schema object.

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

Import the `JSONSchemaBuilder` target and improve schema generation ergonomics with Swift's result builders.

```swift
@JSONSchemaBuilder var jsonSchema: JSONSchemaComponent {
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

jsonSchema.schema // Same `Schema` type as above for quick serialization
```

## Installation

You can add the SwiftJSONSchema package to your project using Swift Package Manager (SPM) or Xcode.

### Using Swift Package Manager (SPM)

To add SwiftJSONSchema to your project using Swift Package Manager, add the following dependency to your Package.swift file:

```swift
dependencies: [
    .package(url: "https://github.com/ajevans99/swift-json-schema", from: "1.0.0")
]
```

Then, include `JSONSchema` and/or `JSONSchemaBuilder` as a dependency for your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "JSONSchema", package: "swift-json-schema"),
            .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
        ]
    )
]
```

### Using Xcode

1. Open your project in Xcode.
2. Navigate to File > Swift Packages > Add Package Dependency...
3. Enter the repository URL: https://github.com/ajevans99/swift-json-schema
4. Follow the prompts to add the package to your project.

Once added, you can import `JSONSchema` in your Swift files and start using it in your project.

## Documentation

The full documentation for this library is available through the Swift Package Index.

[View the documentation](https://swiftpackageindex.com/ajevans99/swift-json-schema)

## Next Steps

This library is in active development. If you have any feedback or suggestions, please open an issue or pull request.

Goals for future releases include:
- [ ] [Support `const` keyword](https://json-schema.org/understanding-json-schema/reference/const#constant-values)
- [ ] [Support schema composition (`allOf`, `anyOf`, `oneOf`, `not`)](https://json-schema.org/understanding-json-schema/reference/combining#allof)
- [ ] [Support applying subschemas conditionally](https://json-schema.org/understanding-json-schema/reference/conditionals)
- [ ] Support `$ref` and `$defs` keywords
- [ ] Support enums in result builders
- [ ] Root schema in result builders
- [ ] Support multiple types like `{ "type": ["number", "string"] }`
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
@JSONSchemaBuilder static var schemaRepresentation: JSONSchemaComponent {
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
