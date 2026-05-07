# ``JSONSchema``

The ``JSONSchema`` target provides the core runtime for working with JSON Schema documents in Swift. It focuses on representing schemas, decoding/encoding them, validating data, and navigating JSON documents with strongly typed utilities.

## Overview

- **Schema representation** – ``Schema`` loads schemas from Swift builders, JSON strings, or decoded `JSONValue` instances.
- **JSON data model** – ``JSONValue`` models any JSON payload, enabling type-safe validation and letting you construct instances directly in Swift without juggling `Any`.
- **Pointer navigation** – ``JSONPointer`` provide convenient traversal of deeply nested JSON structures and map cleanly onto the JSON Schema specification's pointer syntax.
- **Validation pipeline** – Calling ``Schema/validate(_:)`` returns a ``ValidationResult`` containing errors, annotations, and metadata about which keywords were evaluated. You can emit spec-compliant diagnostics through ``ValidationOutputLevel`` and ``ValidationOutputConfiguration``.
- **Format validators** – The ``FormatValidator`` registry ships with built-in validators (URI, email, hostname, UUID, duration, and more) and lets you register custom implementations to extend your dialect.
- **Dialect support** – ``Dialect`` encapsulates draft-specific features (like metaschemas, vocabulary requirements, and `$dynamicRef` semantics). You can opt into draft 2020-12 or supply your own dialect definition.
- **Codable integration** – ``JSONValue``, ``Schema``, annotations, and validation results all conform to Swift's `Codable` protocols, making it straightforward to serialize or inspect them in tooling.

## Validation Lifecycle

```swift
let schema = try Schema(instance: schemaJSONData)
let payload: JSONValue = ["name": "Ada", "age": 37]

let result = schema.validate(payload)

if result.isValid {
	print("Document is valid")
} else {
	for error in result.errors ?? [] {
		print("Keyword", error.keyword, "failed at", error.instanceLocation)
	}
}

let verboseOutput = try result.renderedOutput(level: .verbose)
```

Validation is spec-compliant: references resolve through ``JSONPointer`` paths, annotations flow through in-place applicators, and custom formats/dialects participate automatically. The repository keeps a synchronized copy of the official JSON Schema Test Suite (including the output tests), and `swift test` runs every draft 2020-12 fixture to maintain compatibility.

## Topics

### Core Types

- ``Schema``
- ``JSONValue``
- ``JSONPointer``
- ``ValidationResult``

### Validation Output

- ``ValidationOutputLevel``
- ``ValidationOutputConfiguration``

### Infrastructure

- ``FormatValidator``
- ``Dialect``
