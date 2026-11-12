# Migrating to scalar-exact object keys

The additive `JSONKey` utilities are available independently of the coordinated object
migration. **The following object shape is planned, source-breaking, and unreleased**;
adding these utilities alone does not change `JSONValue.object`.

## Why the representation changes

JSON member names use decoded Unicode-scalar identity. Swift String treats `"é"` and
`"e\u{301}"` as equal, so a String-keyed dictionary cannot preserve both names. Do not
normalize them. `JSONKey` stores the original String with scalar-exact equality/hash.

The coordinated migration changes:

```swift
// Before
case object(OrderedDictionary<String, JSONValue>)
// After
case object(OrderedDictionary<JSONKey, JSONValue>)
```

The `.object` accessor, core evaluated-name annotations, property-collection parse
signatures, and typed additional-property result keys change accordingly. Existing
enum case matching remains `.object(let members)`; there is no alternate hidden case.
String literals and String subscript conveniences wrap names without normalization.
Use `key.rawValue` when a String is needed, and `JSONKey(name)` when constructing
name-keyed collections. Public builder property names may remain String inputs.

## Explicit dictionary interoperability

```swift
let source: [String: Int] = ["count": 1]
let exact = OrderedDictionary<JSONKey, Int>(stringKeyed: source)
let ordered = try exact.stringKeyed()
let dictionary = try exact.stringKeyedDictionary()
```

Importing a Swift dictionary preserves only the members it still contains. It cannot
recover scalar-distinct names discarded before the call. For pairs not yet inserted
into a dictionary, use `init(stringKeyedPairs:)`; exact duplicates retain the last
value and move to the last position. Scalar-distinct names remain separate.

Both export methods throw `JSONKeyConversionError.canonicalCollision` if Swift String
keys would merge names. No default winner or lossy normalization is provided.

## Codable boundary

`JSONKey` itself encodes as a single string. After the coordinated object migration,
encoding `JSONValue` through generic keyed Codable containers will reject canonical
key collisions with `EncodingError.invalidValue`, including nested objects, instead
of silently dropping a member. Use OrderedJSON's raw serializer for exact output.

Generic Foundation decoding cannot promise preservation: a decoder may collapse keys
before exposing its keyed container. Decode raw JSON with `JSONValue.parse` when
member identity, order, and number tokens matter. A successful JSONDecoder round trip
does not prove source preservation.

The standard library may encode a standalone `Dictionary<JSONKey, Value>` as an array,
not a JSON object; the object-encoding guarantee applies to `JSONValue`, not arbitrary
generic collections.

## Coordinated consumer changes

Custom property collections must migrate String-keyed parse inputs to scalar-keyed
inputs. Typed additional-property outputs use scalar keys; explicitly export only
when the destination truly requires a String dictionary. Numeric pointer tokens and
array-index syntax retain their existing rules, while object-token equality becomes
scalar-exact. Macro source names do not need normalization or rewritten spellings.

Existing data containing both canonical spellings now retains both values; equality,
hashing, required/dependent/property validation and reference lookup intentionally
stop aliasing them. Review stored expectations and downstream String-key conversions
before adopting the breaking release.
