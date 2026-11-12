# ReferenceResolver

`ReferenceResolver` resolves `$ref` and `$dynamicRef` against a base URI using the
context's registered documents, identifiers, anchors, and compiled-schema caches.
It does not perform HTTP requests or asynchronous loading. Applications load external
documents and supply their parsed values through `Context(remoteSchema:)`.

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

## Caching, dynamic scope, and ownership

The resolver caches its initial static target. Compiled remote documents are cached
under their retrieval URI and canonical `$id`; relative references still use the
document's declared base URI.

`$dynamicRef` rechecks the current evaluation's dynamic scope on every call when its
initial target defines the matching `$dynamicAnchor`. Dynamic overrides are not cached
as static targets or shared across independent evaluations.

Public schemas retain context storage. Cached local graphs borrow that storage, and
resolvers keep local target keys rather than owning the graphs they can belong to.
Resolved schemas retain storage before escaping the cache. Meta-schema targets have
independent contexts and can be retained directly. Preserve these ownership boundaries
when changing caching; otherwise recursive references can create retain cycles.

## Measuring changes

The [benchmark suite](Benchmarks/README.md) already includes reference-heavy construction,
validation, and output workloads. Compare time and allocations before changing caches;
there is no network-fetch cost in these paths.
