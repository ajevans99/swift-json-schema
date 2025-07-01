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
