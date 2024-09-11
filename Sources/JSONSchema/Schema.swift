/// A root JSON schema definition.
///
/// The root schema is the starting point for defining the structure of a JSON document. It provides essential metadata and can include nested schemas for more complex and hierarchical definitions.
///
/// For example, the following root schema specifies that a JSON document must adhere to a particular dialect and can include additional nested schemas:
///
/// ```json
/// {
///   "$schema": "https://json-schema.org/draft/2020-12/schema",
///   "$id": "https://example.com/schemas/myschema",
///   "vocabulary": {
///     "https://json-schema.org/draft/2020-12/vocab/core": true,
///     "https://json-schema.org/draft/2020-12/vocab/applicator": true
///   },
///   "type": "object",
///   "properties": {
///     "name": { "type": "string" }
///   },
///   "required": ["name"]
/// }
/// ```
///
/// This root schema provides the base structure and vocabulary for defining and validating JSON documents.
///
/// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/about)
///
/// - SeeAlso: ``Schema``
@dynamicMemberLookup public struct RootSchema: Equatable, Sendable {
  /// An optional identifier for the schema. When serialized, this will appear as `$id`.
  /// The `$id` keyword is used to define a base URI for the schema. This base URI is used to resolve relative URIs within the schema.
  /// An example value is `/schemas/address` (relative) or `https://example.com/schemas/address` (absolute)
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/structuring.html#id)
  public let id: String?

  /// Used to declare which dialect of JSON Schema the schema was written for. When serialized, this will appear as `$schema`.
  /// The value of the `$schema` keyword is also the identifier for a schema that can be used to verify that the schema is valid according to the dialect `$schema` identifies. A schema that describes another schema is called a "meta-schema".
  /// An example value is `https://json-schema.org/draft/2020-12/schema`
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/schema#schema)
  public let schema: String?

  /// Defines the set of keywords and their associated values that can be used in the schema. When serialized, this will appear as `$vocabulary`.
  /// Each entry in the vocabulary object maps a keyword to a boolean or an object. If the value is true, it means that the keyword is mandatory. If it is false, the keyword is optional.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/schema#schema)
  public let vocabulary: [String: JSONValue]?

  /// The actual JSON schema definition.
  ///
  /// This will be serialized at the same level as the other properties of this struct, without the keyword `subschema`
  ///
  /// For example, the subschema can define the structure of nested objects within the root schema:
  ///
  /// ```json
  /// {
  ///   "$schema": "https://json-schema.org/draft/2020-12/schema",
  ///   "$id": "https://example.com/schemas/myschema",
  ///   "vocabulary": {
  ///     "https://json-schema.org/draft/2020-12/vocab/core": true,
  ///     "https://json-schema.org/draft/2020-12/vocab/applicator": true
  ///   },
  ///   // The following properties are the subschema ↴
  ///   "type": "object",
  ///   "properties": {
  ///     "name": { "type": "string" }
  ///   },
  ///   "required": ["name"]
  /// }
  /// ```
  ///
  /// The ``Schema/type`` must always be `.object`. The `subschema` allows for defining detailed structures and validation rules for nested objects within the root schema. Subschema properties can be accessed directly through dynamic member lookup.
  public let subschema: Schema?

  /// Direct access to ``RootSchema/subschema`` properties.
  ///
  /// Optional `T` helps prevent double optional unwrapping issues.
  public subscript<T>(dynamicMember keyPath: KeyPath<Schema, T?>) -> T? {
    subschema?[keyPath: keyPath] ?? nil
  }

  public init(
    id: String? = nil,
    schema: String? = nil,
    vocabulary: [String: JSONValue]? = nil,
    subschema: Schema? = nil
  ) {
    self.id = id
    self.schema = schema
    self.vocabulary = vocabulary
    self.subschema = subschema
  }
}

/// A JSON schema definition.
///
/// A schema definition is a JSON object that defines the structure of a JSON document. A schema definition can be used to validate a JSON document, and to provide additional information about the document's structure.
///
/// For example, the following schema definition specifies that a JSON document must be an object with a `name` property that is a string:
///
/// ```json
/// {
///   "type": "object",
///   "properties": {
///     "name": { "type": "string" }
///   },
///   "required": ["name"]
/// }
/// ```
///
/// This schema definition can be used to validate a JSON document like this:
///
/// ```json
/// {
///   "name": "Alice"
/// }
/// ```
///
/// The schema definition can also be used to provide additional information about the structure of the JSON document. For example, the following schema definition specifies that the `name` property should be a string with a maximum length of 100 characters:
///
/// ```json
/// {
///   "type": "object",
///   "properties": {
///     "name": {
///       "type": "string",
///       "maxLength": 100
///     }
///   },
///   "required": ["name"]
/// }
/// ```
///
/// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/about)
///
/// - SeeAlso: ``RootSchema``
public struct Schema: Sendable {
  /// Specifies the data type for the schema.
  /// Optional to support schemas that are not tied to a specific type.
  public let type: JSONType?

  /// Additional options specific to the schema type.
  /// Type-erased to support `Codable` conformance.
  public let options: AnySchemaOptions?

  /// Additional annotations for the schema.
  public let annotations: AnnotationOptions

  /// An array of possible values for the schema.
  /// TODO: Use `OrderedSet` from `swift-collections` to ensure uniqueness
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/enum)
  public let enumValues: [JSONValue]?

  /// Composition options for the schema.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/combining)
  public let composition: CompositionOptions?
  /// A single value that the schema must match.
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/const#constant-values)
  public let const: JSONValue?

  /// Creates a schema definition for a string type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the string type.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition for a string type.
  public static func string(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: StringSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: .string,
      options: options.eraseToAnySchemaOptions(),
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition for an integer type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition for an integer type.
  public static func integer(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: .integer,
      options: nil,
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition for a number type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the number type.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition for a number type.
  public static func number(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: NumberSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: .number,
      options: options.eraseToAnySchemaOptions(),
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition for an object type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the object type.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition for an object type.
  public static func object(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: ObjectSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: .object,
      options: options.eraseToAnySchemaOptions(),
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition for an array type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the array type.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition for an array type.
  public static func array(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: ArraySchemaOptions = .options(),
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: .array,
      options: options.eraseToAnySchemaOptions(),
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition for a boolean type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition for a boolean type.
  public static func boolean(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: .boolean,
      options: nil,
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition for a null type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition for a null type.
  public static func null(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: .null,
      options: nil,
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition with no explicit type.
  ///
  /// Example:
  /// ```json
  /// {
  ///   "enum" : ["1", 2, null, 4.5]
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options for any type.
  ///   - enumValues: An array of possible values for the schema.
  ///   - composition: Composition options for the schema.
  /// - Returns: A schema definition with no explicit type.
  public static func noType(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: (any SchemaOptions)? = nil,
    enumValues: [JSONValue]? = nil,
    composition: CompositionOptions? = nil
  ) -> Schema {
    .init(
      type: nil,
      options: options?.eraseToAnySchemaOptions(),
      annotations: annotations,
      enumValues: enumValues,
      composition: composition,
      const: nil
    )
  }

  /// Creates a schema definition that only accepts a single value.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - value: The value that the schema must match.
  ///   - type: The type of the value. This is optional and can be inferred from the value.
  /// - Returns: A schema definition that accepts only a constant.
  public static func const(
    _ annotations: AnnotationOptions = .annotations(),
    _ value: JSONValue,
    type: JSONType? = nil
  ) -> Schema {
    .init(
      type: type,
      options: nil,
      annotations: annotations,
      enumValues: nil,
      composition: nil,
      const: value
    )
  }
}
