# ``JSONSchema``

Validate JSON against Draft 2020-12 schemas and inspect structured diagnostics.

## Overview

Use `JSONSchema` directly when you already have a schema document. You do not need macros,
result builders, or a Swift model to validate JSON. To generate schemas from Swift instead,
see [`JSONSchemaBuilder`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschemabuilder).

`JSONSchema` re-exports
[`OrderedJSON`](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/orderedjson),
including its `JSONValue` type and parser that preserves object order and number tokens.

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

`Schema(instance:)` is a convenience initializer for JSON strings that uses `JSONValue.parse`
by default, retaining source key order and numeric tokens. The overload accepting an explicit
`JSONDecoder` is deprecated and remains only for compatibility. `Schema` and `JSONValue` also
conform to `Codable`, but Foundation decoding cannot guarantee original number precision.
Decoding `Schema` with `JSONDecoder`
initializes a default Draft 2020-12 context, including local-reference resolution and
support for `validateAgainstMetaSchema()`. Use `Schema(rawSchema:context:)` when you need
external schemas or custom format validators.

## Reuse a schema

A `Schema` is `Sendable` and can be cached and validated concurrently. Each public validation
call has independent conditional results and dynamic-reference scopes, including a reentrant
call from a custom format validator. Nested applicators and references retain the scope of their
own evaluation. Reference definitions and caches are shared, with synchronized updates.

Custom format validators are also `Sendable`; synchronize any mutable state they own.

## Exact numeric validation

Numeric bounds and `multipleOf` compare exact `JSONNumberLiteral` values, without converting
the instance or schema constraint to `Double`:

```swift
let priceSchema = try Schema(
  instance: #"{"type":"number","multipleOf":0.01,"maximum":9.27}"#
)
print(try priceSchema.validate(instance: "9.270").isValid) // true
```

JSON Schema's `integer` type is mathematical: `1.0` and `1e2` are integers regardless of
spelling. Validation is independent of a destination Swift type's precision and range;
a valid JSON number can still fail conversion to `Int`, `Double`, or Foundation `Decimal`.
General `multipleOf` arithmetic has a bounded work budget and reports failures explicitly rather than
falling back to approximate validation.

Count constraints (`minLength` / `maxLength`, `minItems` / `maxItems`, `minProperties` /
`maxProperties`, and `minContains` / `maxContains`) also compare exact literals. Bounds must
be mathematical nonnegative integers; `2.0` is accepted. Huge bounds are not converted to
`Int` or `Double` and silently replaced with permissive defaults:

```swift
let manyItems = try Schema(instance: #"{"type":"array","minItems":1e1000}"#)
print(manyItems.validate([]).isValid) // false
```

See the [numeric migration guide](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/orderedjson/migrating-to-lossless-numbers)
for enum-case, accessor, and `Codable` changes.

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
