# Macros

Generate typed schemas from Swift models, then customize their JSON representation.

## Generate and use a schema

Apply `@Schemable` to a struct, class, or enum to generate a static `schema`
property and conformance to ``Schemable``. The schema both describes JSON and
parses it into your Swift type; it does not require `Codable`.

```swift
import JSONSchemaBuilder

@Schemable
struct Person {
  let name: String
  let age: Int?
}

let person = try Person.schema.parseAndValidate(
  instance: #"{"name":"Morgan","age":null}"#
)
// person.name == "Morgan"; person.age == nil
```

Use `schema.schemaValue` to inspect the generated JSON Schema, or
`schema.definition()` to obtain a validator without constructing the Swift model.
Use `parseAndValidate` when you need both a typed result and JSON Schema
validation. See <doc:Validation> for the distinction between parsing and validation.

For structs and classes, the macro includes explicitly typed, non-static stored
properties in declaration order. It skips computed properties. The generated
schema calls `Type.init`, so an initializer must accept exactly the included
properties, in the same order and with compatible types. A struct's synthesized
memberwise initializer usually suffices; classes need an explicit initializer.

## Publish a document with shared definitions

Use `Type.document()` to build a self-contained Draft 2020-12 document with `$ref` and
root `$defs`. This is an opt-in construction policy: `Type.schema` and its existing
inline JSON representation are unchanged.

```swift
@Schemable
struct Address {
  static var schemaDefinitionName: String { "Address" }
  let street: String
}

@Schemable
struct Order {
  let shipping: Address

  @SchemaOptions(.description("Billing address"))
  let billing: Address
}

let document = try Order.document(references: .namedTypes)
let jsonSchema = document.definition()
let order = try document.parseAndValidate(
  instance: #"{"shipping":{"street":"A"},"billing":{"street":"B"}}"#
)
```

The root stays inline, while nested named types are extracted even if used only once:

```json
{
  "type": "object",
  "required": ["shipping", "billing"],
  "properties": {
    "shipping": { "$ref": "#/$defs/Address" },
    "billing": { "$ref": "#/$defs/Address", "description": "Billing address" }
  },
  "$defs": {
    "Address": {
      "type": "object",
      "required": ["street"],
      "properties": { "street": { "type": "string" } }
    }
  }
}
```

``SchemaDocument`` is a typed ``JSONSchemaComponent``. `schemaValue`, `definition()`,
`parse`, and `parseAndValidate` use the same document structure, including references.
Construction retains the registered definition parsers rather than rebuilding them when parsing.
`parse` retains the usual parsing-only contract; use `parseAndValidate` to enforce every constraint.

For a modified or hand-written root, construct it inside the document closure:

```swift
let titled = try SchemaDocument {
  Order.schema.title("Checkout request")
}

let addresses = try SchemaDocument {
  JSONArray {
    JSONReusable(Address.self)
  }
}
```

``JSONReusable`` passes through its schema when no document is being constructed. Inside a
document it registers the type's schema once and emits a reference. The macro uses the same
building block for inferred named types, including array elements, dictionary keys and values,
and enum payloads. Explicit `.customSchema(...)` conversions stay inline.
Named schema providers do not need to conform to `Schemable`: the macro supplies their `.schema`
through the `JSONReusable(_:inline:schema:)` closure initializer, preserving their output type.
That closure must supply the type's canonical schema; apply per-use modifications outside it.

### Names and inline overrides

Definition keys default to sanitized, fully qualified Swift type names. Private/local compiler
context addresses are removed. Keys are not based on schema equality: distinct Swift types are
not merged merely because their schemas have the same shape. Definitions are emitted in sorted
key order. Sanitization can cause collisions; collisions with other generated definitions or
existing root `$defs` entries throw ``SchemaDocumentError`` instead of renaming or overwriting.

Override `schemaDefinitionName` for a stable published name, as above. Explicit keys are escaped
as JSON Pointer tokens and URI fragments. To opt a type out of extraction, implement:

```swift
static var schemaDocumentBehavior: SchemaDocumentBehavior { .inline }
```

For one hand-written use, choose `JSONReusable(Address.self, inline: true)`.

### Current document boundaries

- `.namedTypes` is the only policy currently supported; repeated-use-only extraction is deferred.
- Construction uses a scoped registration context. Build components inside the closure.
  Already-built children, including those in a cached `static let schema`, are not traversed
  to discover reuse. A new `JSONReusable` wrapper can register a cached schema as a whole,
  but cannot retroactively extract its children. There is no general JSON deduplication pass.
- Finish schema modifications inside the closure. Do not replace generated reference JSON or
  structurally mutate a finalized document. Document-created reusable components must be parsed
  through their owning document.
- Only annotations (`title`, `description`, `default`, `examples`, `deprecated`, `readOnly`,
  `writeOnly`, and `$comment`) may sit beside generated `$ref`s. Other sibling keywords throw.
  The macro conservatively keeps named fields inline when they have constraint modifiers or
  type-style nullability. For nullable references in hand-written builders, use
  `.orNull(style: .union)` or `.unionAnyOf`, not `.type`.
- Recursive named definitions retain one `$dynamicAnchor`, and recursive parsing uses the retained
  parser. Duplicate anchors, including duplicates caused by customized inline recursive uses,
  throw rather than silently changing recursive constraints. Mutual construction cycles throw;
  use the existing macro self-reference support for direct recursion.
- Documents currently reject `$id`, explicit `$schema`, `$vocabulary`, `$anchor`, legacy recursive
  keywords, and non-generated `$ref` targets. `$dynamicRef` must target a local declared dynamic
  anchor. External resources and arbitrary existing-reference bundles should continue to use
  the regular builder/reference APIs and a validation context, not this document API.
- Constructing a document inside another document's construction closure throws. Each independent
  document owns its registration state; parsing does not add definitions. A completed document
  must be used as a root, not embedded in another schema: its local references address its root
  `$defs`. Compose original `.schema` values or `JSONReusable` components instead.

## Supported types and collections

| Swift property type | Generated component |
| --- | --- |
| `String` | ``JSONString`` |
| `Bool` | ``JSONBoolean`` |
| `Int` | ``JSONInteger`` |
| `Double` | ``JSONNumber`` |
| `Decimal`, `Foundation.Decimal` | ``JSONDecimal`` |
| `[Element]`, `Array<Element>` | ``JSONArray`` with an element schema |
| `[String: Value]`, `Dictionary<String, Value>` | ``JSONObject`` with an `additionalProperties` schema |
| `[Key: Value]` with a suitable `Schemable` key | ``JSONObject`` with `propertyNames` and `additionalProperties` schemas |
| Another `Schemable` model, including qualified names such as `Catalog.Book` | That type's `schema` |
| `T?` | An optional property; see missing and null values below |

Collections can contain other collections or models:

```swift
@Schemable
struct Book {
  let title: String
  let authors: [String]
}

@Schemable
enum Shelf {
  case fiction
  case reference
}

@Schemable
struct Library {
  let featured: Book
  let booksByShelf: [Shelf: [Book]]
  let ratingsByReader: [String: [Int]]
}
```

Dictionary keys are still JSON strings. A custom key's schema must parse those
strings into a hashable key value; simple `@Schemable` enums such as `Shelf` work.
Primitive numeric dictionary keys are not supported.

The macro recognizes `Float` but currently emits `JSONNumber()`, whose output is
`Double`. Use `Double` or a custom schema that explicitly converts to `Float`.
`Decimal` and `Foundation.Decimal` are recognized directly, including optional properties,
array elements, and dictionary values. They use exact decimal conversion rather than
converting a `Double`:

```swift
import Foundation

@Schemable
struct Invoice {
  let amount: Decimal
  let discount: Foundation.Decimal?
  let adjustments: [Decimal]
  let totalsByCurrency: [String: Decimal]
}
```

`JSONDecimal` rejects numbers that are inexact or out of range for Foundation `Decimal`.
Other named types are assumed to provide a static `schema`; there is no automatic
conversion for other Foundation types, `Set`, or arbitrary numeric types. Unsupported syntax such
as tuples and function types is diagnosed and omitted, which can also cause an
initializer mismatch. Prefer `T?` for optional properties; nullable collection
elements and other unsupported type shapes need a hand-written schema.

## Enums

Enums without associated values use JSON strings. The strings are case names,
or raw values for `String`-backed enums:

```swift
@Schemable
enum Size: String {
  case small = "sm"
  case medium = "md"
  case large = "lg"
}
```

For example, the JSON string `"md"` parses as `Size.medium`. Numeric raw values
are not used to generate numeric enum schemas; write a custom schema for that
representation.

Enums with associated values use ``JSONComposition`` with `oneOf` by default:

```swift
@Schemable
enum Forecast {
  case cloudy(Double)
  case rainy(chance: Double, amount: Double)
  case clear
}
```

The corresponding JSON shapes are:

```json
{"cloudy":{"_0":18.5}}
```

```json
{"rainy":{"chance":0.8,"amount":12}}
```

```json
"clear"
```

The case name is a required object property. Labeled associated values use their
labels; unlabeled values use `_0`, `_1`, and so on. Non-optional associated values
are required. Cases without associated values remain strings, even in a mixed enum.
Optional associated values may be omitted, but the automatic null handling for
struct and class properties described below is not applied to enum parameters.

For consumers that require `anyOf`, configure the composition explicitly:

```swift
@Schemable(enumComposition: .anyOf)
enum Response {
  case success(message: String)
  case failure(code: Int)
}
```

`oneOf` requires exactly one matching branch; `anyOf` permits one or more. This
changes validation semantics for overlapping branches, not just the emitted
keyword. `enumComposition` only affects enums with associated values.

## JSON property names

Property names follow this priority, from highest to lowest:

1. `@SchemaOptions(.key("..."))` on the property.
2. An entry in a nested `CodingKeys` enum.
3. The `keyStrategy` passed to `@Schemable`.
4. The Swift property name.

```swift
@Schemable(keyStrategy: .snakeCase)
struct Customer {
  let firstName: String

  @SchemaOptions(.key("surname"))
  let lastName: String

  let middleName: String?

  enum CodingKeys: String, CodingKey {
    case firstName = "given_name"
    case lastName = "last_name"
  }
}
```

This schema uses `given_name`, `surname`, and `middle_name`. An entry in
`CodingKeys` without a raw value preserves the case name rather than applying the
strategy. A property omitted from `CodingKeys` is **not excluded** from the schema;
it falls back to the strategy or its Swift name.

``KeyEncodingStrategies`` provides `.identity`, `.snakeCase`, and `.kebabCase`,
plus `.custom(MyStrategy.self)` for a type conforming to ``KeyEncodingStrategy``.
These options control schema property names, not a `JSONEncoder` configuration.

## Missing fields, null, and defaults

For struct and class properties:

| Declaration | Missing field | Explicit JSON `null` |
| --- | --- | --- |
| Non-optional `T` | Rejected | Rejected by the usual non-null schema |
| `T?` with the default `optionalNulls: true` | Produces `nil` | Produces `nil` |
| `T?` with `optionalNulls: false` | Produces `nil` | Rejected by the usual non-null schema |

The macro intentionally collapses missing fields and explicit nulls to the same
Swift `nil` under its default behavior. To allow omission but reject null, opt out
at the type level. You can restore null support for individual optional properties:

```swift
@Schemable(optionalNulls: false)
struct Profile {
  let name: String
  let email: String?

  @SchemaOptions(.orNull(style: .type))
  let age: Int?
}
```

``OrNullStyle`` controls the emitted schema:

- `.type` adds `"null"` to a type array, such as `["integer", "null"]`.
- `.union` wraps the value schema and a null schema in `oneOf`.
- `.unionAnyOf` wraps them in `anyOf`.

With automatic null handling enabled, scalar primitives use `.type`; collections
and other models use `.union`. Set `optionalNullUnion: .anyOf` on `@Schemable`
to use `anyOf` for those implicit unions. This is independent of
`enumComposition` and does not change scalar type arrays.

### Defaults are annotations, not fallback values

`@SchemaOptions(.default(...))` adds JSON Schema metadata. It does not fill in a
missing property, replace null, or make a non-optional property optional:

```swift
@Schemable
struct Preferences {
  @SchemaOptions(.default("system"))
  let theme: String
}
```

`theme` is still required when parsing JSON. The macro also copies supported
primitive and collection initializer expressions into `.default(...)`; these
expressions must be representable as a JSON value. Defaults for nested model
instances are not inferred. If using Swift property defaults, prefer `var` when
relying on a synthesized memberwise initializer: an initialized `let` is not a
memberwise initializer parameter.

## Descriptions and constraints

Documentation comments on stored properties become schema descriptions.
An explicit `.description(...)` takes precedence over the comment.

```swift
@Schemable
@SchemaOptions(.title("Account"))
@ObjectOptions(.additionalProperties { false })
struct Account {
  /// The display name shown to other users.
  @StringOptions(.minLength(1), .maxLength(80))
  let name: String

  @SchemaOptions(.description("Age in years"))
  @NumberOptions(.minimum(0), .maximum(130))
  let age: Int

  @ArrayOptions(.maxItems(10))
  let tags: [String]
}
```

Use `@SchemaOptions` for annotations such as title, description, examples,
default, read-only, write-only, deprecated, and comment. Type-level annotations
apply to the root schema. Use `@StringOptions`, `@NumberOptions`, `@ArrayOptions`,
and `@ObjectOptions` for type-specific constraints. For example, the object option
above rejects properties not declared in `Account`.

`@NumberOptions` supports both `Double` and `JSONNumberLiteral` arguments for `minimum`,
`maximum`, `exclusiveMinimum`, `exclusiveMaximum`, and `multipleOf`. Use a validated
`JSONNumberLiteral` constant constructed from a string for bounds that must not first round
through `Double`; for example, `.multipleOf(cent)` where
`let cent = try JSONNumberLiteral("0.01")`. The `Double` overloads require finite inputs.
Constraints are validated exactly regardless of whether the property is `Int`, `Double`,
or `Decimal`. See <doc:Validation> for exact decimal parsing.

Documentation comments also work directly on enum associated-value parameters:

```swift
@Schemable
enum Connection {
  case database(
    /// The database connection string.
    url: String,
    /// Maximum number of connections.
    poolSize: Int
  )
}
```

Type-level documentation comments are not automatically copied to the root schema;
use `@SchemaOptions(.description(...))` there.

## Exclude properties

`@ExcludeFromSchema` removes a stored property from schema generation. Supply an
initializer that accepts all remaining properties in declaration order and
initializes the excluded value itself:

```swift
@Schemable
struct Weather {
  let temperature: Double
  let units: String
  let location: String

  @ExcludeFromSchema
  let internalNote: String

  init(temperature: Double, units: String, location: String) {
    self.temperature = temperature
    self.units = units
    self.location = location
    self.internalNote = "Not supplied by JSON"
  }
}
```

Exclusion does not configure `Codable` or prohibit an extra JSON key. Use
`@ObjectOptions(.additionalProperties { false })` if undeclared keys must be
rejected.

## Custom schemas

Use `@SchemaOptions(.customSchema(...))` when a property's schema or conversion
cannot be inferred. Pass a type conforming to ``Schemable`` whose schema output
matches the Swift property type:

```swift
struct NonEmptyString: Schemable {
  static var schema: some JSONSchemaComponent<String> {
    JSONString().minLength(1)
  }
}

@Schemable
struct Label {
  @SchemaOptions(.customSchema(NonEmptyString.self))
  let text: String
}
```

`NonEmptyString` is a schema provider, not the stored property's type.
Put `.customSchema(...)` first if combining it with other schema options: it
replaces the inferred schema and any options applied before it. Normal property
requiredness and optional-null handling still apply.

The `JSONSchemaConversion` module provides schema providers for Foundation types
such as `UUID`, `Date`, and `URL`. For complete control over object shape,
initializer mapping, or unsupported type syntax, implement ``Schemable/schema``
manually with the builder instead of applying `@Schemable`.

## Recursive models

Direct self-references in struct and class properties are recognized, including
references inside arrays and dictionaries:

```swift
@Schemable
struct TreeNode {
  let name: String
  let children: [TreeNode]
}
```

The macro emits a ``JSONDynamicReference`` at each self-reference and a matching
`$dynamicAnchor` on the object schema. This keeps schema construction finite and
lets validation follow the same schema for every child. A leaf still needs
`"children": []` because the property is non-optional.

This is direct self-reference support, not general cycle detection across types.
Mutually recursive models and recursive enum associated values are not
automatically rewritten into references. Write explicit schemas with
``JSONReference`` or ``JSONDynamicReference`` and matching definitions or anchors
for those cases. Swift's own recursive-storage restrictions still apply: a struct
cannot store another instance of itself directly, even as an optional; use a
collection, a class, or another valid indirection.
