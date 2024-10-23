# Swift JSON Schema

[![CI](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fswift-json-schema%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ajevans99/swift-json-schema)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fswift-json-schema%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ajevans99/swift-json-schema)

The Swift JSON Schema library provides a type-safe way to generate and validate JSON schema documents directly in Swift.

* [Schema Generation](#schema-generation)
* [Macros](#macros)
* [Documentation](#documentation)
* [Installation](#installation)
* [Next Steps](#next-steps)
* [License](#license)

## Schema Generation

Use the power of Swift result builders to generate JSON schema documents.

```swift
@JSONSchemaBuilder var personSchema: some JSONSchemaComponent {
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

<details>
  <summary>Generated JSON Schema</summary>
  
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
</details>

## Macros

Use the `@Schemable` macro from `JSONSchemaBuilder` to automatically generate the result builders.

```swift
@Schemable
struct Person {
  let firstName: String
  let lastName: String?
  @NumberOptions(minimum: 0, maximum: 120)
  let age: Int
}
```

<details>
  <summary>Expanded Macro</summary>

  ```swift
  struct Person {
    let firstName: String
    let lastName: String?
    let age: Int

    // Auto-generated schema ↴
    static var schema: some JSONSchemaComponent<Person> {
      JSONSchema(Person.init) {
        JSONObject {
          JSONProperty(key: "firstName") {
            JSONString()
          }
          .required()
          JSONProperty(key: "lastName") {
            JSONString()
          }
          JSONProperty(key: "age") {
            JSONInteger()
            .minimum(0)
            .maximum(120)
          }
          .required()
        }
      }
    }
  }
  extension Person: Schemable {}
  ```

</details>
<br/>

`@Schemable` can be applied to enums.

```swift
@Schemable
enum Status {
  case active
  case inactive
}
```

<details>
  <summary>Expanded Macro</summary>

  ```swift
  enum Status {
    case active
    case inactive
    
    static var schema: some JSONSchemaComponent<Status> {
      JSONString()
        .enumValues {
          "active"
          "inactive"
        }
        .compactMap {
          switch $0 {
          case "active":
            return Self.active
          case "inactive":
            return Self.inactive
          default:
              return nil
          }
        }
      }
  }
  extension Status: Schemable {}
  ```

</details>
<br/>

Enums with associated values are also supported using `anyOf` schema composition. See the [JSONSchemaBuilder documentation](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder) for more information.

## Parsing and Validation



## Documentation

The full documentation for this library is available through the Swift Package Index.

- [JSONSchema Documentation](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema)
- [JSONSchemaBuilder Documentation](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder)

## Installation

You can add the SwiftJSONSchema package to your project using Swift Package Manager (SPM) or Xcode.

### Using Swift Package Manager (SPM)

To add SwiftJSONSchema to your project using Swift Package Manager, add the following dependency to your Package.swift file:

```swift
dependencies: [
  .package(url: "https://github.com/ajevans99/swift-json-schema", from: "0.2.1")
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

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
