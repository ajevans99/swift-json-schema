# Ordered vs. Foundation

When to reach for `OrderedJSON` instead of `JSONDecoder`/`JSONEncoder` or `JSONSerialization`.

## Overview

Apple's `Foundation` ships two JSON APIs (`JSONDecoder`/`JSONEncoder` for `Codable` types, and `JSONSerialization` for untyped trees). Both are well-tested and fast. `OrderedJSON` exists for one specific reason they don't cover: **byte-stable output across processes and platforms**, with the full untyped JSON tree as the value type.

This article compares the three so you can pick the right one for your use case.

## The comparison

| Operation | `JSONDecoder` | `JSONSerialization` | `OrderedJSON` |
|-----------|--------------|--------------------|--------------| 
| Decodes into your `Codable` Swift types | ✅ | ❌ (gives `[String: Any]`) | ❌ (gives `JSONValue`) |
| Untyped tree | ❌ (would need `JSONValue: Codable`) | ✅ (`Any`) | ✅ (`JSONValue`) |
| Object key order preserved on **parse** | ❌ unspecified | ✅ iOS 17+/macOS 14+/tvOS 17+/watchOS 10+ only | ✅ all platforms |
| Object key order preserved on **emit** | ❌ unspecified | ❌ alphabetical with `.sortedKeys`; unspecified otherwise | ✅ insertion order |
| Round-trip byte-stable | ❌ | ⚠️ recent Apple platforms only | ✅ |
| RFC 8259 strict | ✅ | ✅ | ✅ |
| Linux parity | ⚠️ corelibs Foundation | ⚠️ key order not guaranteed | ✅ |
| Custom number-vs-double policy | ⚠️ via `Decimal` | ⚠️ via `NSNumber` introspection | ✅ explicit (``JSONValue/integer(_:)`` vs ``JSONValue/number(_:)``) |
| Streaming / chunked input | ❌ | ❌ | ❌ (planned) |

> Foundation's key-order behavior is not promised by `JSONDecoder` / `JSONEncoder` — it's implementation-defined and shouldn't be relied on. `JSONSerialization` *does* preserve insertion order on iOS 17+ / macOS 14+ / tvOS 17+ / watchOS 10+ where the parser was rewritten to do so; older OS versions and corelibs Foundation (Linux) make no such promise.

## When to pick what

### Use `JSONDecoder` / `JSONEncoder` when

- You have a `Codable` Swift type and want the JSON tree mapped onto it. *That's what they're for.*
- Output key order doesn't matter (most production code).
- You're already deep in the `Codable` ecosystem with custom `init(from:)` / `encode(to:)` implementations.

### Use `JSONSerialization` when

- You need an untyped tree, you're Apple-platform-only, and you target iOS 17+/macOS 14+ where key order is preserved.
- You're integrating with an Objective-C codebase that already uses `NSDictionary` / `NSArray`.

### Use `OrderedJSON` when

- You need **byte-stable output across processes** (snapshot testing, signed payloads, generated artifacts, diff-friendly logs).
- You need **Linux/cross-platform key-order preservation** — Foundation's `JSONSerialization` only preserves order on recent Apple OSes.
- You want **explicit integer-vs-number disambiguation** instead of `NSNumber` introspection.
- You're building tooling on top of [`JSONSchema`](https://swiftpackageindex.com/ajevans99/swift-json-schema) — the validator's deterministic output guarantee depends on `OrderedJSON`.

## Performance

`OrderedJSON`'s parser and serializer are written for **correctness and readability first**. They pass all 318 [`nst/JSONTestSuite`](https://github.com/nst/JSONTestSuite) cases and round-trip byte-stably, but they aren't yet tuned for throughput. Foundation's parsers benefit from years of tuning.

If your workload is parser-bound (large payloads, high request rate), benchmark before you switch. For typical schema-validation, snapshot-testing, and config-file-loading workloads, the throughput difference is unlikely to matter.

See [issue #162](https://github.com/ajevans99/swift-json-schema/issues/162) for the perf roadmap.

## Migrating from `JSONDecoder` to `OrderedJSON`

```diff
- let dict = try JSONDecoder().decode([String: AnyCodable].self, from: data)
+ let value = try JSONValue.parse(data)
+ guard case .object(let dict) = value else { /* handle */ return }
```

```diff
  let raw: [String: Any] = ["name": "Ada", "age": 37]
- let bytes = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
+ let value: JSONValue = ["name": "Ada", "age": 37]
+ let bytes = try value.serializedData()
```
