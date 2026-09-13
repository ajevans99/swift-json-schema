# Value Builder

## Overview

You can also use the ``JSONValueBuilder`` result builder to create JSON values (a.k.a. instances or documents).

```swift
@JSONValueBuilder var jsonValue: JSONValueRepresentable {
  JSONArrayValue {
    JSONStringValue("Hello, world!")
    JSONNumberValue(number: 42)
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

## Exact numeric values

`JSONNumberValue` also accepts a validated `JSONNumberLiteral`. Use a string constructor
when precision or token spelling matters:

```swift
let amount = try JSONNumberLiteral("9.270")
let number = JSONNumberValue(number: amount)
print(try number.value.serialized()) // 9.270
```

Swift floating-point literals and the `Double` initializer cannot recover digits already
rounded by Swift. The `Double` initializer requires a finite value; use the throwing
`JSONNumberLiteral(Double)` initializer for untrusted numeric input.
