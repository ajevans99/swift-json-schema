# ``JSONSchema``

Validate JSON against Draft 2020-12 schemas and inspect structured diagnostics.

## Overview

Use `JSONSchema` directly when you already have a schema document. You do not need macros,
result builders, or a Swift model to validate JSON. To generate schemas from Swift instead,
see [`JSONSchemaBuilder`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder).

`JSONSchema` re-exports
[`OrderedJSON`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/orderedjson),
including its `JSONValue` type and order-preserving parser.

## Load a schema and validate input

```swift
import JSONSchema

let schemaJSON = """
{
  "type": "object",
  "properties": {
    "name": { "type": "string", "minLength": 1 },
    "age": { "type": "integer", "minimum": 0 }
  },
  "required": ["name", "age"]
}
"""

let schema = try Schema(
  rawSchema: JSONValue.parse(schemaJSON),
  context: Context(dialect: .draft2020_12)
)
let payload: JSONValue = ["name": "Ada", "age": -1]
let result = schema.validate(payload)
print(result.isValid) // false

let diagnostics = try result.renderedOutput(level: .basic)
print(try diagnostics.serialized(options: .pretty))
```

``ValidationResult`` contains validity, nested errors, annotations, and keyword/instance
locations. Basic output flattens errors to help locate the failing value; in this example,
the `minimum` error points to `/age`. See <doc:Validation-output-formats> for the available
diagnostic levels.

`Schema(instance:)` is a convenience initializer for JSON strings that uses `JSONDecoder`
by default. Use `JSONValue.parse` as above when you want to retain source key order.
`Schema` and `JSONValue` also conform to `Codable`.

## References and external schemas

Schemas can use `$defs`, `$ref`, `$anchor`, and dynamic references. Register external documents
by URI when constructing the validation context:

```swift
let context = Context(
  dialect: .draft2020_12,
  remoteSchema: [
    "https://example.com/nonempty-string": [
      "type": "string",
      "minLength": 1,
    ]
  ]
)
let referenced = try Schema(
  rawSchema: ["$ref": "https://example.com/nonempty-string"],
  context: context
)
print(referenced.validate(.string("Ada")).isValid) // true
```

The registry supplies the documents; validation does not automatically fetch them over the
network. Load external resources in your application and pass their parsed JSON values here.
``JSONPointer`` provides navigation through nested JSON documents.

## Enable format validation

The default context has no format validators. To enforce supported string formats, provide
``DefaultFormatValidators/all``:

```swift
let emailSchema = try Schema(
  rawSchema: ["type": "string", "format": "email"],
  context: Context(
    dialect: .draft2020_12,
    formatValidators: DefaultFormatValidators.all
  )
)
print(emailSchema.validate(.string("not-an-email")).isValid) // false
```

The registry includes date/time, email, hostname, IP address, UUID, URI, and URI-reference
validators. To register an application-specific format, implement ``FormatValidator`` with
a `formatName` and `validate(_:)` method, then include it in `formatValidators`. Each
registered format name must be unique. A format without a registered validator is not asserted.

The `ipv6` validator accepts the address forms in RFC 4291 section 2.2: eight hexadecimal
groups, a single `::` compressing one or more zero groups, and an optional dotted-decimal
IPv4 tail occupying the final two groups. IPv4 octets must be ASCII decimal values from
0 through 255 without leading zeros. Only bare addresses are accepted, not URI brackets,
ports, zone identifiers such as `%eth0`, or CIDR prefixes such as `/64`.

## Check a schema itself

Constructing a `Schema` is different from checking it against the dialect's meta-schema:

```swift
let schemaCheck = try schema.validateAgainstMetaSchema()
print(schemaCheck.isValid)
```

``Dialect`` controls keywords and vocabulary behavior; the built-in dialect is Draft 2020-12.
The repository includes the official JSON Schema Test Suite, and the README's Bowtie badge
links to the published compliance report.

## Topics

### Guides

- <doc:Validation-output-formats>
- <doc:Deterministic-schema-output>

### Core types

- ``Schema``
- ``JSONPointer``
- ``ValidationResult``

### Validation configuration

- ``Context``
- ``Dialect``
- ``FormatValidator``
- ``DefaultFormatValidators``
- ``ValidationOutputLevel``
- ``ValidationOutputConfiguration``

### Deterministic JSON

- ``Schema/jsonValue``
- ``ValidationResult/jsonValue``
- ``ValidationError/jsonValue``
