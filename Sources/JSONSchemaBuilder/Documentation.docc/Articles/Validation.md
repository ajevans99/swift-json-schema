# Parsing and validation

Turn JSON into Swift values while enforcing your schema's constraints.

## Choose the right operation

| Operation | Result | Use it when |
| --- | --- | --- |
| `component.parseAndValidate(value)` | Your Swift output, or a thrown ``ParseAndValidateIssue`` | Input must both satisfy the schema and convert to your model. |
| `component.definition().validate(value)` | `ValidationResult` | You need validity and diagnostics without constructing a Swift model. |
| `component.parse(value)` | ``Parsed`` with ``ParseIssue`` values on failure | You need conversion without independently enforcing every schema keyword. |

The `instance: String` parsing overloads also throw if JSON decoding fails. Primitive parsers
check JSON types, but `parse` alone is not a substitute for schema validation: for example,
`JSONString().minLength(5).parse(.string("hi"))` still produces a string.

## Map a builder into a Swift type

```swift
import JSONSchemaBuilder

struct Item {
  let name: String
  let price: Double
}

let itemSchema = JSONObject {
  JSONProperty(key: "name") {
    JSONString().minLength(1)
  }
  .required()

  JSONProperty(key: "price") {
    JSONNumber().minimum(0)
  }
  .required()
}
.map(Item.init)

let item: Item = try itemSchema.parseAndValidate(
  instance: #"{"name": "iPad", "price": 199.99}"#
)
print(item.name) // iPad
```

Object properties produce a tuple in declaration order. `.map(Item.init)` transforms that tuple
into a model; ``JSONSchema`` also accepts a transform and a builder closure. See <doc:WrapperTypes>
for other transformations, or <doc:Macros> to generate the builder from a Swift type.

Properties are optional unless marked `.required()`. Required means the key must be present;
whether its value may be `null` depends on the property's schema. Use `.orNull()` to accept
explicit nulls. Macro-generated schemas infer required and nullable behavior from Swift types.

## Handle invalid input

```swift
do {
  let item = try itemSchema.parseAndValidate(
    instance: #"{"name": "", "price": -1}"#
  )
  print(item)
} catch {
  switch error {
  case .decodingFailed(let underlying):
    print("Invalid JSON:", underlying)
  case .parsingFailed(let issues):
    print("Could not construct Item:", issues)
  case .validationFailed(let result):
    print("Schema constraints failed:", result.errors ?? [])
  case .parsingAndValidationFailed(let issues, let result):
    print("Parsing issues:", issues)
    print("Schema constraints failed:", result.errors ?? [])
  }
}
```

Schema diagnostics include keyword and instance locations. For machine-readable diagnostics,
use `result.renderedOutput(level: .basic)`; see the
[validation output guide](https://swiftpackageindex.com/ajevans99/swift-json-schema/main/documentation/jsonschema/validation-output-formats).

## Formats and ordered input

Enable format validation explicitly when your schema uses `format` constraints:

```swift
import JSONSchema

let context = Context(
  dialect: .draft2020_12,
  formatValidators: DefaultFormatValidators.all
)
let email = try JSONString().format("email").parseAndValidate(
  instance: #""ada@example.com""#,
  validationContext: context
)
```

The default context has no format validators. Custom implementations of `FormatValidator`
can be passed in the same registry.

String parsing overloads use `JSONDecoder` by default. When source key order matters, parse
with `JSONValue.parse` first and pass the resulting value to `parseAndValidate` or `parse`.

## Composition parsing

Compositions validate each branch's schema before running its parser. Constraints such as
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
