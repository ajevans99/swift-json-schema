import Foundation

public struct ToolContext: Codable {
  public let name: String
  public let description: String
  public let parameters: OldJSONSchema

  public init(name: String, description: String, parameters: OldJSONSchema) {
    self.name = name
    self.description = description
    self.parameters = parameters
  }
}

public enum JSONType: String, Codable {
  case string
  case number
  case integer
  case object
  case array
  case boolean
  case null
}

public struct OldJSONSchema: Codable {
  public let type: JSONType
  public let properties: [String: Property]?
  public let required: [String]?

  public struct Property: Codable {
    public let type: JSONType
    public let description: String?
    public let enumValues: [String]?

    public init(type: JSONType, description: String? = nil, enumValues: [String]? = nil) {
      self.type = type
      self.description = description
      self.enumValues = enumValues
    }
  }

  public init(type: JSONType, properties: [String: Property]? = [:], required: [String]? = nil) {
    self.type = type
    self.properties = properties
    self.required = required
  }
}

public struct JSONStringOptions: JSONSchemaOptions {

  /// Minimum length of string.The value must be a non-negative number.
  /// https://json-schema.org/understanding-json-schema/reference/string#length
  public let minLength: Int?

  /// Maximum length of string.The value must be a non-negative number.
  /// https://json-schema.org/understanding-json-schema/reference/string#length
  public let maxLength: Int?
  
  /// Restrict a string to a particular regular expression.
  /// https://json-schema.org/understanding-json-schema/reference/string#regexp
  public let pattern: String?
  
  /// Allows for basic semantic identification of certain kinds of string values that are commonly used.
  /// https://json-schema.org/understanding-json-schema/reference/string#format
  public let format: String?

  public init(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    format: String? = nil
  ) {
    self.minLength = minLength
    self.maxLength = maxLength
    self.pattern = pattern
    self.format = format
  }
}

public struct JSONNumberOptions: JSONSchemaOptions {
  /// Restrictes value to a multiple of this number.
  /// https://json-schema.org/understanding-json-schema/reference/numeric#multiples
  public let multipleOf: Double?

  /// Maximum value.
  /// https://json-schema.org/understanding-json-schema/reference/numeric#range
  public let minimum: RangeValue?

  /// Minimum value.
  /// https://json-schema.org/understanding-json-schema/reference/numeric#range
  public let maximum: RangeValue?

  public enum RangeValue: Codable {
    case exclusive(Double)
    case inclusive(Double)
  }

  public init(
    multipleOf: Double? = nil,
    minimum: RangeValue? = nil,
    maximum: RangeValue? = nil
  ) {
    self.multipleOf = multipleOf
    self.minimum = minimum
    self.maximum = maximum
  }
}

public struct JSONObjectOptions: JSONSchemaOptions {
  /// Key is the name of a property and each value is a schema used to validate that property.
  /// https://json-schema.org/understanding-json-schema/reference/object#properties
  public let properties: [String: AnyJSONSchemaOptions]?

  /// Key is a regular expression and each value is a schema use to validate that property.
  /// If a property name matches the given regular expression, the property value must validate against the corresponding schema.
  /// https://json-schema.org/understanding-json-schema/reference/object#patternProperties
  public let patternProperties: [String: AnyJSONSchemaOptions]?

  /// Used to control the handling of properties whose names are not listed in the `properties` keyword or match any of the regular expressions in the `patternProperties` keyword.
  /// By default any additional properties are allowed.
  /// If `.disabled`, no additional properties (not listed in `properties` or `patternProperties`) will be allowed.
  /// https://json-schema.org/understanding-json-schema/reference/object#additionalproperties
  public let additionalProperties: SchemaOrDisabledValue?

  /// Similar to `additionalProperties` except that it can recognize properties declared in subschemas.
  /// https://json-schema.org/understanding-json-schema/reference/object#unevaluatedproperties
  public let unevaluatedProperties: SchemaOrDisabledValue?

  /// List of property keywords that are required.
  /// https://json-schema.org/understanding-json-schema/reference/object#required
  public let required: [String]?

  /// Schema options to validate property names against.
  /// https://json-schema.org/understanding-json-schema/reference/object#propertyNames
  public let propertyNames: JSONStringOptions?

  /// Minimum number of properties.
  /// https://json-schema.org/understanding-json-schema/reference/object#size
  public let minProperties: Int?

  /// Maximum number of properties.
  /// https://json-schema.org/understanding-json-schema/reference/object#size
  public let maxProperties: Int?

  public init(
    properties: [String: AnyJSONSchemaOptions]? = nil,
    patternProperties: [String: AnyJSONSchemaOptions]? = nil,
    additionalProperties: SchemaOrDisabledValue? = nil,
    unevaluatedProperties: SchemaOrDisabledValue? = nil,
    required: [String]? = nil,
    propertyNames: JSONStringOptions? = nil,
    minProperties: Int? = nil,
    maxProperties: Int? = nil
  ) {
    self.properties = properties
    self.patternProperties = patternProperties
    self.additionalProperties = additionalProperties
    self.unevaluatedProperties = unevaluatedProperties
    self.required = required
    self.propertyNames = propertyNames
    self.minProperties = minProperties
    self.maxProperties = maxProperties
  }
}

public struct JSONArrayOptions: JSONSchemaOptions {
  /// Each element of the array must match the given schema.
  /// If `.disabled`, array elements beyond what are provided in `prefixItems` are not allowed.
  /// https://json-schema.org/understanding-json-schema/reference/array#items
  public let items: SchemaOrDisabledValue?

  /// Each item is a schema that corresponds to each index of the document's array. That is, an array where the first element validates the first element of the input array, the second element validates the second element of the input array, etc.
  /// https://json-schema.org/understanding-json-schema/reference/array#tupleValidation
  public let prefixItems: [AnyJSONSchemaOptions]?

  /// Applies to any values not evaluated by an `items`, `prefixItems`, or `contains` keyword.
  /// https://json-schema.org/understanding-json-schema/reference/array#unevaluateditems
  public let unevaluatedItems: SchemaOrDisabledValue?

  /// Specifies schema that must be valid against one or more items in the array.
  /// https://json-schema.org/understanding-json-schema/reference/array#contains
  public let contains: AnyJSONSchemaOptions?

  /// Used with `contains` to minimum number of times a schema matches a `contains` constraint.
  /// https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains
  public let minContains: Int?

  /// Used with `contains` to maximum number of times a schema matches a `contains` constraint.
  /// https://json-schema.org/understanding-json-schema/reference/array#mincontains-maxcontains
  public let maxContains: Int?

  /// Minimum number of items in the array.
  /// https://json-schema.org/understanding-json-schema/reference/array#length
  public let minItems: Int?

  /// Maximum number of items in the array.
  /// https://json-schema.org/understanding-json-schema/reference/array#length
  public let maxItems: Int?

  /// Ensure that each of the items in array is unique.
  /// https://json-schema.org/understanding-json-schema/reference/array#uniqueItems
  public let uniqueItems: Bool?

  public init(
    items: SchemaOrDisabledValue? = nil,
    prefixItems: [AnyJSONSchemaOptions]? = nil,
    unevaluatedItems: SchemaOrDisabledValue? = nil,
    contains: AnyJSONSchemaOptions? = nil,
    minContains: Int? = nil,
    maxContains: Int? = nil,
    minItems: Int? = nil,
    maxItems: Int? = nil,
    uniqueItems: Bool? = nil
  ) {
    self.items = items
    self.prefixItems = prefixItems
    self.unevaluatedItems = unevaluatedItems
    self.contains = contains
    self.minContains = minContains
    self.maxContains = maxContains
    self.minItems = minItems
    self.maxItems = maxItems
    self.uniqueItems = uniqueItems
  }
}

/// Part of schema that isn't strictly used for validation, but are used to describe parts of a schema
/// https://json-schema.org/understanding-json-schema/reference/annotations#annotations
public struct JSONAnnotationOptions<JSONData: Codable>: Codable {
  /// Short title about the purpose of the data described by the schema.
  public let title: String?
  
  /// Longer description about the purpose of the data described by the schema.
  public let description: String?
  
  /// Non-validation tools such as documentation generators or form generators may use this value to give hints to users about how to use a value.
  /// However, default is typically used to express that if a value is missing, then the value is semantically the same as if the value was present with the default value.
  public let `default`: (JSONData)?

  /// An array of examples that validate against the schema.
  public let examples: [JSONData]?

  /// Indicates that a value should not be modified.
  public let readOnly: Bool?
  
  /// Indicates that a value may be set, but will remain hidden.
  public let writeOnly: Bool?

  /// Indicates that the instance value the keyword applies to should not be used and may be removed in the future.
  public let deprecated: Bool?

  /// Strictly intended for adding comments to a schema.
  /// TODO: Coding Key needs to be "$comment". Should this be seperate from JSONAnnotation?
  public let comment: String?

  public init(
    title: String? = nil,
    description: String? = nil,
    `default`: (JSONData)? = nil,
    examples: [JSONData]? = nil,
    readOnly: Bool? = nil,
    writeOnly: Bool? = nil,
    deprecated: Bool? = nil,
    comment: String? = nil
  ) {
    self.title = title
    self.description = description
    self.`default` = `default`
    self.examples = examples
    self.readOnly = readOnly
    self.writeOnly = writeOnly
    self.deprecated = deprecated
    self.comment = comment
  }
}

public enum SchemaOrDisabledValue: Codable {
  case schema(AnyJSONSchemaOptions)
  case disabled
}

//public indirect enum JSONSchema: Codable {
//  case string(JSONStringOptions)
//  case integer
//  case number(JSONNumberOptions)
//  case object(JSONObjectOptions)
//  case array(JSONArrayOptions)
//  case boolean
//  case null
//}

public protocol JSONSchemaOptions: Codable {}

public struct AnyJSONSchemaOptions: Codable {
  private let value: JSONSchemaOptions
  private let encodeFunc: (Encoder) throws -> Void

  public init<T: JSONSchemaOptions>(_ value: T) {
    self.value = value
    self.encodeFunc = { encoder in
      try value.encode(to: encoder)
    }
  }

  public func encode(to encoder: Encoder) throws {
    try encodeFunc(encoder)
  }

  public init(from decoder: Decoder) throws {
    fatalError("Do we really need to decode?")
  }
}


public struct Schema<JSONData: Codable> {
  let type: JSONType
  let options: (any JSONSchemaOptions)?
  let annotations: JSONAnnotationOptions<JSONData>?

  public static func string(
    _ options: JSONStringOptions = .init(),
    _ annotations: JSONAnnotationOptions<String>? = nil
  ) -> Schema<String> {
    .init(type: .string, options: options, annotations: annotations)
  }

  public static func integer(
    _ annotations: JSONAnnotationOptions<Int>? = nil
  ) -> Schema<Int> {
    .init(type: .integer, options: nil, annotations: annotations)
  }

  public static func number(
    _ options: JSONNumberOptions = .init(),
    _ annotations: JSONAnnotationOptions<Double>? = nil
  ) -> Schema<Double> {
    .init(type: .number, options: options, annotations: annotations)
  }

  public static func object(
    _ options: JSONObjectOptions = .init(),
    _ annotations: JSONAnnotationOptions<JSONData>? = nil
  ) -> Schema<JSONData> {
    .init(type: .object, options: options, annotations: annotations)
  }

  public static func array(
    _ options: JSONArrayOptions = .init(),
    _ annotations: JSONAnnotationOptions<[JSONData]>? = nil
  ) -> Schema<[JSONData]> {
    .init(type: .array, options: options, annotations: annotations)
  }

  public static func boolean(
    _ annotations: JSONAnnotationOptions<Bool>? = nil
  ) -> Schema<Bool> {
    .init(type: .boolean, options: nil, annotations: annotations)
  }

  @available(iOS 17.0, macOS 14.0, *) // Never conforms to decodable in newer versions only TODO: tvOS, watchOS
  public static func null(
    _ annotations: JSONAnnotationOptions<Optional<Never>>? = nil
  ) -> Schema<Optional<Never>> {
    .init(type: .null, options: nil, annotations: annotations)
  }
}
