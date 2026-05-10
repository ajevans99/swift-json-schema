# Conditional Validation

Learn how to use conditional keywords like ``dependentRequired`` and the ``If`` builder to model relationships between schema properties.

Use ``dependentRequired`` when the presence of one property requires another:

```swift
@JSONSchemaBuilder var creditInfo: some JSONSchemaComponent {
  JSONObject {
    JSONProperty(key: "credit_card") { JSONInteger() }
    JSONProperty(key: "billing_address") { JSONString() }
  }
  .dependentRequired(["credit_card": ["billing_address"]])
}
```

> Note: ``JSONSchemaComponent/dependentRequired(_:)``,
> ``JSONSchemaComponent/dependentSchemas(_:)``, and
> ``JSONSchemaComponent/vocabulary(_:)`` accept Swift's `KeyValuePairs`
> rather than `Dictionary`. The dictionary-literal call site is unchanged
> — `["credit_card": ["billing_address"]]` works as written — but the
> declaration order of keys is preserved through to the emitted JSON.
> A `Dictionary` would have been hash-seed-randomized at the literal-init
> step, leaking nondeterministic order into your output.

You can also build conditional schemas using the ``If`` helper:

```swift
@JSONSchemaBuilder var conditional: some JSONSchemaComponent {
  If({ JSONString().minLength(1) }) {
    JSONString().pattern("^foo")
  } else: {
    JSONString().pattern("^bar")
  }
}
```
