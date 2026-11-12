# Proposal: scalar-exact JSON object keys

**Status: plan approved by Austin; implementation in progress, unreleased.**
Austin's approval, relayed in the coordinating request: "234 plan seems reasonable to me".
This design-only draft still makes no representation or runtime change. Additive utilities
and their guide are reviewed separately in #235; the coordinated migration is a second layer.
Baseline: `f8539c863d5651380b9a7b013e43ccc2b37e9e60`. This addresses quality-audit C1,
separately from the scoped regex correction.

## Confirmed problem

```json
{"\u00e9":1,"e\u0301":2}
```

These are two different JSON names. The public representation,
`JSONValue.object(OrderedDictionary<String, JSONValue>)`, uses Swift's canonical
String equality and retains only one. Singleton objects with those different names
also compare equal; pointers and schema property-name lookups alias them.

Four temporary package integration tests on the baseline failed with six issues:
member count, singleton equality, pointer equality/lookup, `required`, and `properties`.
The tests were removed from the shipping suite because this proposal does not fix them.
They can be reproduced with the cases below; this is not a green implementation.

| Operation | Correct result | Baseline result |
| --- | --- | --- |
| Parse the object above | Two ordered members | One member |
| Compare `{"\u00e9":1}` and `{"e\u0301":1}` | Unequal | Equal |
| Compare pointers with those respective name tokens | Unequal | Equal |
| Resolve `/e` + U+0301 in `{"\u00e9":1}` | Missing | Value `1` |
| Validate `{"e\u0301":1}` against `{"required":["\u00e9"]}` | Invalid | Valid |
| Validate it against `{"properties":{"\u00e9":false}}` | Valid | Invalid |

Normalization is not a solution: both names must remain distinct. Changing object
equality alone cannot recover members already discarded by parsing or dictionary construction.

## Recommended representation

Introduce a small `JSONKey` value type storing the original `String`. Its equality
compares Unicode scalars verbatim; its hash combines the same scalar sequence rather
than calling `String.hash(into:)`. It is `Sendable`, `Hashable`, and
`ExpressibleByStringLiteral`. Do not cache additional arrays without measurement.

For the breaking migration, change object storage and the `.object` accessor to
`OrderedDictionary<JSONKey, JSONValue>`, optionally named `JSONValue.Object` by a
typealias. Keep the existing enum case name and order-insensitive object equality;
preserve insertion order for emission. This uses the existing ordered collection
rather than introducing an unrelated object hierarchy.

Keep String-facing convenience entry points where they can wrap names immediately.
Direct dictionary literals can preserve the incoming sequence of pairs by wrapping
each key before insertion. String variables used with raw object-storage subscripts
need explicit `JSONKey` construction or a clearly labeled String convenience.
Scalar identity is based on decoded names, not JSON escape spelling: `"e"` and
`"\u0065"` are the same key.

An exact duplicate still follows the existing last-occurrence-wins value **and position**
rule. Canonically equivalent but scalar-distinct names are not duplicates.

## Required end-to-end migration

The parser must wrap a decoded name before its first keyed insertion. Serialization
must emit the stored original name. Object equality/hash must use scalar keys and
remain independent of member order.

Migrate every name-keyed intermediate collection, not just `JSONValue`:

- Core `properties`, `required`, dependencies, `$defs`, evaluated-property sets, and
  annotations must use scalar identity.
- JSON Pointer token equality/hash and object lookup must agree on scalar names.
  Preserve the existing equivalence of numeric index `0` and object token `"0"`,
  while retaining the current array-index syntax rules and `~0`/`~1` escaping.
- Builder property collections, typed pattern/additional-property routing, projected
  parse results, and schema-document definition maps must not round-trip through
  `[String: ...]` or `Set<String>` and lose names again.
- Macro-emitted names remain String source expressions; builder boundaries wrap them.
  Diagnostic locations, reference fragments, anchors, and registry lookups need
  round-trip tests through percent encoding. Do not replace URI-equivalence policy
  with key equivalence indiscriminately.

Changing the object associated value and public property-collection signatures is
source-breaking. Even callers that still compile can observe corrected object
equality, `const`/`enum`/`uniqueItems`, pointer identity, and schema acceptance.

## Interoperability boundaries

An incoming `[String: JSONValue]` may already have discarded distinct names. An
explicit adapter can preserve what it receives, but cannot claim to recover the
original JSON. Prefer raw JSON parsing for scalar-exact input.

Export to a String-keyed dictionary must detect canonical collisions and throw a
specific conversion error. Do not silently normalize, choose a winner, or make
the lossy conversion the default. Any optional lossy policy must be explicit.

Foundation's generic `Codable` keyed-container path cannot guarantee preservation:
a decoder may collapse names before exposing them. Document that boundary rather
than promising collision detection after information is lost. For encoding an
exact object with colliding Swift String names, detect and reject unsupported
String-keyed output rather than silently dropping a member. The raw OrderedJSON
serializer remains the guaranteed scalar-exact route.

## Release and compatibility plan

1. The source-breaking migration, public `JSONKey`/object shape, and strict
   String-dictionary export policy are approved as a plan. The release version,
   implementation review, merging, and publication remain separate decisions.
2. Before switching defaults, land additive key/conversion utilities and a migration
   guide in a separately reviewed change. Do not route the existing parser into a
   new enum case that old `.object` consumers silently miss.
3. Coordinate parser, core, pointer, builder, and macro boundaries in the breaking
   release. Provide before/after examples for enum pattern matching, the object
   accessor, variable-key subscripts, property-collection implementations, and
   dictionary/Codable interop. Deprecate only APIs with a viable replacement.
4. Run correctness, lifetime, concurrent-validation, conformance, and release-mode
   interoperability tests before publication. Keep the #228 ownership fix intact.

There is no complete compatibility-preserving fix within the current public
associated value: its String-keyed storage cannot hold both names. A side table,
normalization, or hidden alternate enum case would sacrifice value semantics,
identity, or existing matching behavior. A separately named opt-in document API
could coexist, but would leave existing `JSONValue` validation incorrect and
duplicate a substantial API surface; it is not the recommended small fix.

## Acceptance tests and measurement

Preserve both example names, their order, and values through parse/serialize/parse.
Check exact duplicates (including escaped equivalents) still move to the last
position. Distinguish singleton objects and pointers; verify order-insensitive
object equality/hash and unequal scalar names in hashed collections.

Exercise `properties`, `required`, dependent keywords, `propertyNames`,
`additionalProperties`, `unevaluatedProperties`, object `const`/`enum`/`uniqueItems`,
definition references, and emitted locations. Cover typed builders and macro
generated code as well as schema JSON. Test strict dictionary-export rejection
and document the limits of generic Foundation decoding.

Measure representative ASCII and combining-key parsing, lookup, hashing, emission,
and wide-object validation in release mode, including allocations. No performance
claim is made by this proposal; correctness and non-lossy conversion are requirements,
not optional benchmark tradeoffs.
