# Value Builder

## Overview

You can also use the ``JSONValueBuilder`` result builder to create JSON values (a.k.a. instances or documents).

```swift
@JSONValueBuilder var jsonValue: JSONValueRepresentable {
  JSONArrayValue {
    JSONStringValue("Hello, world!")
    JSONNumberValue(42)
  }
}
```

or use the literal extensions for JSON values.

```swift
@JSONValueBuilder var jsonValue: JSONValueRepresentable {
  [
    "Hello, world!",
    42
  ]
}
```
