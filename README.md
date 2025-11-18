# Swift JSON Schema

[![CI](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml/badge.svg)](https://github.com/ajevans99/swift-json-schema/actions/workflows/ci.yml)
[![SPI Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fswift-json-schema%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ajevans99/swift-json-schema)
[![SPI Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fajevans99%2Fswift-json-schema%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ajevans99/swift-json-schema)
[![Supported Dialects](https://img.shields.io/endpoint?url=https%3A%2F%2Fbowtie.report%2Fbadges%2Fswift-swift-json-schema%2Fsupported_versions.json)](https://bowtie.report/#/implementations/swift-swift-json-schema)
[![Draft 2020-12](https://img.shields.io/endpoint?url=https%3A%2F%2Fbowtie.report%2Fbadges%2Fswift-swift-json-schema%2Fcompliance%2Fdraft2020-12.json)](https://bowtie.report/#/implementations/swift-swift-json-schema)
[![codecov](https://codecov.io/gh/ajevans99/swift-json-schema/graph/badge.svg?token=P5CGW5A95K)](https://codecov.io/gh/ajevans99/swift-json-schema)

The Swift JSON Schema library provides a type-safe way to generate and validate JSON schema documents directly in Swift.

* [Schema Generation](#schema-generation)
* [Macros](#macros)
* [Validation](#validation)
* [Parsing](#parsing)
* [Example Projects](#example-projects)
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

  `Schema` returned from `personSchema.definition()` conforms to `Codable`.

  ```swift
  let encoder = JSONEncoder()
  encoder.outputFormatting = .prettyPrinted

  let schemaData = try! encoder.encode(personSchema.definition())
  let string = String(data: schemaData, encoding: .utf8)!
  print(string)
  ```
  
  ```json
  {
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
@ObjectOptions(.additionalProperties { false })
struct Person {
  let firstName: String

  let lastName: String?

  @NumberOptions(.minimum(0), .maximum(120))
  let age: Int

  /// A short bio or summary about the person, shown on their public profile.
  @StringOptions(.maxLength(500))
  let bio: String?
}
```

<details>
  <summary>Expanded Macro</summary>

  ```swift
  struct Person {
    let firstName: String

    let lastName: String?

    let age: Int

    /// A short bio or summary about the person, shown on their public profile.
    let bio: String?

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
              JSONProperty(key: "bio") {
                  JSONString()
                  .maxLength(500)
                  .description(#"""
                  A short bio or summary about the person, shown on their public profile.
                  """#)
              }
          }
          .additionalProperties(false)
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

For details on modeling dependencies and other conditional constructs, check the [Conditional Validation guide](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder/ConditionalValidation).

## Validation

Using the `Schema` type, you can validate JSON data against a schema.

```swift
let schemaString = """
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "minLength": 1
    }
  }
}
"""
let schema1 = try Schema(instance: schemaString)
let result = try schema1.validate(instance: #"{"name": "Alice"}"#)
```

Alternatively, you can use the `JSONSchemaBuilder` builders (or [macros](#macros)) to create a schema and validate instances.

```swift
let nameBuilder = JSONObject {
  JSONProperty(key: "name") {
    JSONString()
      .minLength(1)
  }
}
let schema = nameBuilder.defintion()

let instance1: JSONValue = ["name": "Alice"]
let instance2: JSONValue = ["name": ""]

let result1 = schema.validate(instance1)
dump(result1, name: "Instance 1 Validation Result")
let result2 = schema.validate(instance2)
dump(result2, name: "Instance 2 Validation Result")
```

<details>
  <summary>Instance 1 Validation Result</summary>

  ```
  ▿ Instance 1 Validation Result: JSONSchema.ValidationResult
  - isValid: true
  ▿ keywordLocation: #
    - path: 0 elements
  ▿ instanceLocation: #
    - path: 0 elements
  - errors: nil
  ▿ annotations: Optional([JSONSchema.Annotation<JSONSchema.Keywords.Properties>(keyword: "properties", instanceLocation: #, schemaLocation: #/properties, absoluteSchemaLocation: nil, value: Set(["name"]))])
    ▿ some: 1 element
      ▿ JSONSchema.Annotation<JSONSchema.Keywords.Properties>
        - keyword: "properties"
        ▿ instanceLocation: #
          - path: 0 elements
        ▿ schemaLocation: #/properties
          ▿ path: 1 element
            ▿ JSONSchema.JSONPointer.Component.key
              - key: "properties"
        - absoluteSchemaLocation: nil
        ▿ value: 1 member
          - "name"
  ```
</details>

<details>
  <summary>Instance 2 Validation Result</summary>

  ```  ▿ Instance 2 Validation Result: JSONSchema.ValidationResult
  - isValid: false
  ▿ keywordLocation: #
    - path: 0 elements
  ▿ instanceLocation: #
    - path: 0 elements
  ▿ errors: Optional([JSONSchema.ValidationError(keyword: "properties", message: "Validation failed for keyword \'properties\'", keywordLocation: #/properties, instanceLocation: #, errors: Optional([JSONSchema.ValidationError(keyword: "minLength", message: "The string length is less than the specified \'minLength\'.", keywordLocation: #/properties/name/minLength, instanceLocation: #/name, errors: nil)]))])
    ▿ some: 1 element
      ▿ JSONSchema.ValidationError
        - keyword: "properties"
        - message: "Validation failed for keyword \'properties\'"
        ▿ keywordLocation: #/properties
          ▿ path: 1 element
            ▿ JSONSchema.JSONPointer.Component.key
              - key: "properties"
        ▿ instanceLocation: #
          - path: 0 elements
        ▿ errors: Optional([JSONSchema.ValidationError(keyword: "minLength", message: "The string length is less than the specified \'minLength\'.", keywordLocation: #/properties/name/minLength, instanceLocation: #/name, errors: nil)])
          ▿ some: 1 element
            ▿ JSONSchema.ValidationError
              - keyword: "minLength"
              - message: "The string length is less than the specified \'minLength\'."
              ▿ keywordLocation: #/properties/name/minLength
                ▿ path: 3 elements
                  ▿ JSONSchema.JSONPointer.Component.key
                    - key: "properties"
                  ▿ JSONSchema.JSONPointer.Component.key
                    - key: "name"
                  ▿ JSONSchema.JSONPointer.Component.key
                    - key: "minLength"
              ▿ instanceLocation: #/name
                ▿ path: 1 element
                  ▿ JSONSchema.JSONPointer.Component.key
                    - key: "name"
              - errors: nil
  - annotations: nil
  ```
</details>
<br/>

## Parsing

When using [builders](#schema-generation) or [macros](#macros), you can also parse JSON instances into Swift types.

```swift
@Schemable
enum TemperatureUnit {
  case celsius
  case fahrenheit
}

@Schemable
struct Weather {
  let temperature: Double
  let unit: TemperatureUnit
  let conditions: String
}

let data = """
{
  "temperature": 20,
  "unit": "celsius",
  "conditions": "Sunny"
}
"""
let weather: Parsed<Weather, ParseIssue> = Weather.schema.parse(instance: data)
```

Optionally, combine parsing and validation in a single step.

```swift
let weather: Weather = try Weather.schema.parseAndValidate(instance: data)
```

> Shoutout to the [swift-parsing](https://github.com/pointfreeco/swift-parsing) library and the [Point-Free Parsing series](https://www.pointfree.co/collections/parsing) for the inspiration behind the parsing API and implementation.

## Example Projects

Explore these companion repositories to see `swift-json-schema` in action:

- [SwiftFunctionToolsExperiment](https://github.com/ajevans99/SwiftFunctionToolsExperiment) – demonstrates creating type-safe [OpenAI API function tool calls](https://platform.openai.com/docs/guides/function-calling) using schemas built with this library.
- [swift-mcp-toolkit](https://github.com/ajevans99/swift-mcp-toolkit) – a toolkit built on top of the official Model Context Protocol Swift SDK ([modelcontextprotocol/swift-sdk](https://github.com/modelcontextprotocol/swift-sdk)) that makes it easy to define strongly-typed tools for MCP servers and clients.

Have a project of your own? We'd love to showcase it. Open a PR to add your repository to this list.

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
