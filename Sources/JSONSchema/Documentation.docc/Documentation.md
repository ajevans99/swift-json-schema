# ``JSONSchema``

Generate JSON Schema documents from Swift.

## Overview

### Schema Generation

At the core of the library is the ``Schema`` type, which is used to define the structure of a JSON schema document. The ``RootSchema`` type represents the root of the schema document, and the ``Schema`` type represents a JSON schema object.

The ``Schema`` type provides a variety of factory methods to create different types of JSON schema type. For example, the ``Schema/string(_:_:enumValues:composition:)`` method creates a schema object that represents a string type, and the ``Schema/object(_:_:enumValues:composition:)`` method creates a schema object that represents an object type.

```swift
let veggie = Schema
  .object(
    .annotations(),
    .options(
      properties: [
        "name": .string(
          .annotations(description: "The name of the vegetable.")
        ),
        "veggieLike": .number(
          .annotations(description: "Do I like this vegetable?"),
        )
      ],
      required: ["name", "veggieLike"]
    )
  )

let schema = RootSchema(
  id: "https://example.com/arrays.schema.json",
  schema: "https://json-schema.org/draft/2020-12/schema",
  subschema: .object(
    .annotations(),
    .options(
      properties: [
        "fruits" .array(
          .annotations(),
          .options(items: .string())
        )
        "vegetables": .array(
          .annotations(),
          .options(items: veggie)
        )
      ]
    )
  )
)
```

Composition of schemas is supported with ``CompositionOptions`` on ``Schema/composition``.

#### Annotations

``AnnotationsOptions`` can be added to a schema object using the ``AnnotationOptions/annotations(title:description:default:examples:readOnly:writeOnly:deprecated:comment:)`` factory method. This is the first argument in the ``Schema`` factory methods.

Annotations are used to provide additional information about the schema object. For example, the ``title`` annotation provides a title for the schema object, and the ``description`` annotation provides a description of the schema object. They are typically not used for validation.

```swift
let schema = Schema
  .string(
    .annotations(
      title: "Noun",
      description: "A representation of a person, company, organization, or place."
    )
  )
```

#### Type Specific Options

Each schema type has its own set of options that can be configured using the ``SchemaOptions`` type.

- ``ArraySchemaOptions``
- ``NumberSchemaOptions``
- ``ObjectSchemaOptions``
- ``StringSchemaOptions``

For example, the ``StringSchemaOptions`` type provides options specific to string schema objects, such as ``StringSchemaOptions/minLength``, ``StringSchemaOptions/maxLength``, and ``StringSchemaOptions/pattern``.

```swift
let schema = Schema
  .string(
    .annotations(),
    .options(
      minLength: 1,
      maxLength: 100,
      pattern: "^[a-zA-Z0-9]*$"
    )
  )
```

These options are type-safe and ensure that only valid options are provided for each schema type. They are type-erased using the ``AnySchemaOptions`` type to allow for composition of different schema types and still support `Codable`.

#### Codable

Both `Schema` and `RootSchema` conform to `Codable` for easy serialization into a JSON string (or data) similar to the following:

```json
{
  "$id": "https://example.com/arrays.schema.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "description": "A representation of a person, company, organization, or place",
  "type": "object",
  "properties": {
    "fruits": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "vegetables": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [ "veggieName", "veggieLike" ],
        "properties": {
          "veggieName": {
            "type": "string",
            "description": "The name of the vegetable."
          },
          "veggieLike": {
            "type": "boolean",
            "description": "Do I like this vegetable?"
          }
        }
      }
    }
  },
  "$defs": {
    "veggie": 
  }
}
```

### JSON Instances

The ``JSONValue`` type represents instances (not to be confused with schema or ``JSONType``) of the data.

```swift
let json = JSONValue.object([
  "name": .string("John Doe"),
  "age": .number(30),
  "isEmployed": .boolean(true),
  "address": .object([
    "street": .string("123 Main St."),
    "city": .string("Anytown"),
    "state": .string("NY"),
    "zip": .string("12345")
  ])
])
```

Certain [annotation options](#annotations) require a ``JSONValue`` instance to be created. For example, the ``AnnotationOptions/examples`` option requires a ``JSONValue`` instance to represent the example value.

```swift
let schema = Schema
  .string(
     .annotations(
       examples: .array([
         JSONValue.string("example1"),
         JSONValue.string("example2")
       ])
    )
  )
```

#### Literal Extensions

Literal extensions are provided for convenience when creating JSON instances. For example, the following code creates a JSON object using a dictionary literal:

```swift
let json: JSONValue = [
  "name": "John Doe",
  "age": 30,
  "isEmployed": true,
  "address": [
    "street": "123 Main St.",
    "city": "Anytown",
    "state": "NY",
    "zip": "12345"
  ]
]
```
