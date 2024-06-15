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
public struct Schema {
  /// Specifies the data type for the schema.
  /// Optional to support schemas that are not tied to a specific type.
  let type: JSONType?

  /// Additional options specific to the schema type.
  /// Type-erased to support `Codable` conformance.
  let options: AnySchemaOptions?

  /// Additional annotations for the schema.
  let annotations: AnnotationOptions

  /// An array of possible values for the schema.
  /// TODO: Use `OrderedSet` from `swift-collections` to ensure uniqueness
  /// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/enum)
  let enumValues: [JSONValue]?

  /// Creates a schema definition for a string type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the string type.
  ///   - enumValues: An array of possible values for the schema.
  public static func string(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: StringSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .string, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  /// Creates a schema definition for an integer type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - enumValues: An array of possible values for the schema.
  public static func integer(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .integer, options: nil, annotations: annotations, enumValues: enumValues)
  }

  /// Creates a schema definition for a number type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the number type.
  ///   - enumValues: An array of possible values for the schema.
  public static func number(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: NumberSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .number, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  /// Creates a schema definition for an object type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the object type.
  ///   - enumValues: An array of possible values for the schema.
  public static func object(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: ObjectSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .object, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  /// Creates a schema definition for an array type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - options: Additional options specific to the array type.
  ///   - enumValues: An array of possible values for the schema.
  public static func array(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: ArraySchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .array, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  /// Creates a schema definition for a boolean type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - enumValues: An array of possible values for the schema.
  public static func boolean(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .boolean, options: nil, annotations: annotations, enumValues: enumValues)
  }

  /// Creates a schema definition for a null type.
  ///
  /// - Parameters:
  ///   - annotations: Additional annotations for the schema.
  ///   - enumValues: An array of possible values for the schema.
  public static func null(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .null, options: nil, annotations: annotations, enumValues: enumValues)
  }

  /// Creates a schema definition with no explicit type.
  /// This is a special case. No type is specified, but the schema is still valid.
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
  ///   - enumValues: An array of possible values for the schema.
  public static func noType(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]
  ) -> Schema {
    .init(type: nil, options: nil, annotations: annotations, enumValues: enumValues)
  }
}
