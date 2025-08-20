# Wrapper Types

The builder provides several wrappers that can modify or combine components.

| Wrapper | Description |
| --- | --- |
| ``JSONComponents/AnySchemaComponent`` | Type erasure for heterogeneous components. |
| ``JSONComponents/Map`` | Transforms the output of an upstream component. |
| ``JSONComponents/CompactMap`` | Like ``Map`` but emits an error when the transform returns `nil`. |
| ``JSONComponents/FlatMap`` | Produces a new component after parsing the upstream component. |
| ``JSONComponents/OptionalComponent`` | Makes a wrapped component optional. If no component is provided, any value is accepted. |
| ``JSONComponents/PassthroughComponent`` | Validates with a wrapped component but returns the original input value. |
| ``JSONComponents/AdditionalProperties`` | Adds ``additionalProperties`` validation for objects. |
| ``JSONComponents/PatternProperties`` | Adds ``patternProperties`` validation for objects. |
| ``JSONComponents/PropertyNames`` | Validates and captures property names for objects. |
| ``JSONComponents/Conditional`` | Stores either of two components for ``buildEither`` cases. |
| ``JSONComposition`` wrappers | ``AnyOf``/``AllOf``/``OneOf``/``Not`` compose multiple schemas. |
| ``JSONSchema`` | Groups several components together and optionally maps them to a new type. |
| ``RuntimeComponent`` | Wraps a runtime ``Schema`` and validates returning the raw ``JSONValue``. |
| ``JSONAnyValue`` init | `init(_:)` copies schema metadata from any component without validation. |
