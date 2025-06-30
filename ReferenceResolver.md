# ReferenceResolver

`ReferenceResolver` is responsible for turning the value of `$ref` or `$dynamicRef` keywords into an actual schema that can be used for validation. The resolver works relative to a base URI and relies on context information such as caches and registered identifiers.

## Resolution Flow

1. **Convert the reference** – The reference string is resolved relative to the base URI to form an absolute `URL`. If the reference cannot be parsed, a `ReferenceResolverError.invalidReferenceURI` is thrown.
2. **Load the base schema** – `fetchSchema(for:)` retrieves the schema referenced by the URL. The lookup order is:
   - If the URL matches the current dialect's identifier, the dialect's meta‑schema is loaded. This allows schemas to refer to their own meta‑schema (for example when validating other schemas).
   - A cached schema for the URL, if one exists.
   - A schema registered via `$id` in the identifier registry.
   - A schema stored in the remote schema storage.
   - A workaround for URN references that rely on the base URI.
3. **Resolve fragments or anchors** – If the reference contains a fragment or anchor, `resolveFragmentOrAnchor` locates the subschema within the loaded base schema.
4. **Return the resolved schema** – If none of the steps succeed, `ReferenceResolverError.unresolvedReference` is thrown.

## Why load the meta‑schema?

JSON Schema dialects are themselves described by a schema—often called the *meta‑schema*. When a schema uses `$ref` to point directly to the dialect's meta‑schema (e.g. `https://json-schema.org/draft/2020-12/schema`), the resolver must return that meta‑schema so the reference can be validated. Loading it on demand keeps the meta‑schemas out of the normal cache while still supporting references to them.

## Opportunities for Improvement

- **Cache management**: The resolver currently stores every loaded schema in a flat `schemaCache` dictionary. Introducing expiration policies, size limits, or tiered caches (e.g. in-memory versus on-disk) could reduce memory usage and repeated network fetches. A normalized cache key (such as the canonical URI of a schema) would help avoid duplicates.
- **Asynchronous loading**: Reference resolution always blocks on loading remote schemas. Incorporating async/await would let the resolver fetch multiple references concurrently, improving throughput when validating large schemas with many remote references.
- **Error reporting**: Exposing cache hits and misses in the error messages or diagnostics would make debugging reference issues easier.

## Measuring Resolver Efficiency

To track performance improvements, we can add instrumentation around the resolver:

1. **Time critical paths** – Use `DispatchTime` or `ContinuousClock` to measure how long it takes to resolve a reference and fetch a remote schema. Recording these metrics will highlight slow spots.
2. **Count cache hits and misses** – Maintain counters for how often the cache returns a schema versus fetching or constructing it. These stats help determine whether cache strategies are effective.
3. **Log unresolved references** – Keep a list of references that required remote loading or failed to resolve. This can guide where to pre-populate caches or adjust identifier registration.

Recording these statistics during unit tests or integration benchmarks will provide concrete data to guide future optimizations.
