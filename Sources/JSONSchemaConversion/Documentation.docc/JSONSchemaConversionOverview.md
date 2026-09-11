# ``JSONSchemaConversion``

Convert JSON strings into Foundation values with typed schema providers.

## Overview

Each provider in ``Conversions`` exposes a string schema with a `format` annotation
and a custom parser. Use it directly through `.schema`, in a schema builder, or
with `@SchemaOptions(.customSchema(...))` on a macro-generated property.

## Parse a model

This example validates a JSON object and constructs a Swift model containing a
`UUID`, `Date`, and `URL`:

```swift
import Foundation
import JSONSchemaBuilder
import JSONSchemaConversion

@Schemable
struct Bookmark {
  @SchemaOptions(.customSchema(Conversions.uuid))
  let id: UUID

  @SchemaOptions(.customSchema(Conversions.dateTime))
  let createdAt: Date

  @SchemaOptions(.customSchema(Conversions.url))
  let url: URL
}

let json = """
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "createdAt": "2023-05-01T12:34:56.789Z",
    "url": "https://example.com"
  }
  """

let bookmark = try Bookmark.schema.parseAndValidate(instance: json)
print(bookmark.id.uuidString)
print(bookmark.createdAt.timeIntervalSince1970) // 1682944496.789
print(bookmark.url.absoluteString)             // https://example.com
```

`Conversions.uuid`, `Conversions.dateTime`, and `Conversions.url` are provider
types, not already-built schemas. The macro accesses each provider's `.schema`
and uses its parsed output as the corresponding initializer argument.

## Available conversions

| Provider | Swift output | Parser and example input |
| --- | --- | --- |
| ``Conversions/uuid`` | `UUID` | `UUID(uuidString:)`, e.g. `123e4567-e89b-12d3-a456-426614174000` |
| ``Conversions/dateTime`` | `Date` | `ISO8601DateFormatter` with internet date-time and fractional seconds, e.g. `2023-05-01T12:34:56.789Z` |
| ``Conversions/date`` | `Date` | `DateFormatter` with `yyyy-MM-dd`, `en_US_POSIX`, and UTC, e.g. `2023-05-01` |
| ``Conversions/time`` | `DateComponents` | An ISO 8601 time formatter with fractional seconds and a time zone, e.g. `12:34:56.789Z`; returns time components normalized to UTC |
| ``Conversions/url`` | `URL` | `URL(string:)`, e.g. `https://example.com` |

Date and time acceptance follows the configured Foundation formatters; these
conversions are not general RFC 3339 parsers. In particular, `dateTime` is
configured with `.withFractionalSeconds`: use timestamps with fractional seconds
as above rather than assuming every valid JSON Schema `date-time` string will
parse. The time conversion returns hour, minute, second, nanosecond, and time zone
components, not a calendar date.

The URL conversion accepts whatever `URL(string:)` can construct, including
relative URLs. It does not enforce an absolute URI, an HTTPS scheme, or an
application-specific host allowlist.

## Conversion parsing is separate from format validation

The custom parsers use `compactMap` and reject input when the corresponding
Foundation initializer or formatter returns `nil`. They run during typed parsing
even when JSON Schema format validation is disabled.

By contrast, calling `definition().validate(...)` validates JSON only; it does
not run those Swift conversion closures. The default validation context has no
format validators, so a `format` annotation alone does not reject a malformed
UUID, date, or URI.

To opt into the package's format validators, add `import JSONSchema` and supply
a context when parsing the example above:

```swift
import JSONSchema

let context = Context(
  dialect: .draft2020_12,
  formatValidators: DefaultFormatValidators.all
)
let validatedBookmark = try Bookmark.schema.parseAndValidate(
  instance: json,
  validationContext: context
)
```

This requires both the format validators and the conversion parsers to accept
the input. Their accepted inputs need not be identical: enabling format validation
does not broaden a Foundation formatter's parsing behavior, and successful
Foundation parsing does not by itself prove conformance to a format specification.
