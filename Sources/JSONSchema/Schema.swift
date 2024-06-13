public struct Schema {
  let type: JSONType
  let options: AnySchemaOptions?
  let annotations: AnnotationOptions
  let enumValues: [JSONValue]?

  public static func string(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: StringSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .string, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  public static func integer(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .integer, options: nil, annotations: annotations, enumValues: enumValues)
  }

  public static func number(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: NumberSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .number, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  public static func object(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: ObjectSchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .object, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  public static func array(
    _ annotations: AnnotationOptions = .annotations(),
    _ options: ArraySchemaOptions = .options(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .array, options: options.eraseToAnySchemaOptions(), annotations: annotations, enumValues: enumValues)
  }

  public static func boolean(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .boolean, options: nil, annotations: annotations, enumValues: enumValues)
  }

  public static func null(
    _ annotations: AnnotationOptions = .annotations(),
    enumValues: [JSONValue]? = nil
  ) -> Schema {
    .init(type: .null, options: nil, annotations: annotations, enumValues: enumValues)
  }
}
