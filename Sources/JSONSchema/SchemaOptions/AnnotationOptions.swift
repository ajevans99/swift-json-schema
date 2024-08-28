/// Part of schema that isn't strictly used for validation, but are used to describe parts of a schema
/// [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference/annotations#annotations)
public struct AnnotationOptions: Codable, Sendable {
  /// Short title about the purpose of the data described by the schema.
  public var title: String?

  /// Longer description about the purpose of the data described by the schema.
  public var description: String?

  /// Non-validation tools such as documentation generators or form generators may use this value to give hints to users about how to use a value.
  /// However, default is typically used to express that if a value is missing, then the value is semantically the same as if the value was present with the default value.
  public var `default`: JSONValue?

  /// An array of examples that validate against the schema.
  public var examples: JSONValue?

  /// Indicates that a value should not be modified.
  public var readOnly: Bool?

  /// Indicates that a value may be set, but will remain hidden.
  public var writeOnly: Bool?

  /// Indicates that the instance value the keyword applies to should not be used and may be removed in the future.
  public var deprecated: Bool?

  /// Strictly intended for adding comments to a schema.
  public var comment: String?

  /// Store for annotation results produced by other keywords as defined in section 10.3 of this [JSON Schema](https://json-schema.org/draft/2020-12/json-schema-core#name-keywords-for-applying-subschem) draft.
  public var annotationResults = AnnotationResults()

  enum CodingKeys: String, CodingKey {
    case title, description, `default`, examples, readOnly, writeOnly, deprecated
    case comment = "$comment"
  }

  init(
    title: String? = nil,
    description: String? = nil,
    `default`: (JSONValue)? = nil,
    examples: JSONValue? = nil,
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

  public static func annotations(
    title: String? = nil,
    description: String? = nil,
    `default`: (JSONValue)? = nil,
    examples: JSONValue? = nil,
    readOnly: Bool? = nil,
    writeOnly: Bool? = nil,
    deprecated: Bool? = nil,
    comment: String? = nil
  ) -> Self {
    self.init(
      title: title,
      description: description,
      default: `default`,
      examples: examples,
      readOnly: readOnly,
      writeOnly: writeOnly,
      deprecated: deprecated,
      comment: comment
    )
  }
}

extension AnnotationOptions: Equatable {
  public static func == (lhs: AnnotationOptions, rhs: AnnotationOptions) -> Bool {
    lhs.title == rhs.title && lhs.description == rhs.description && lhs.default == rhs.default && lhs.examples == rhs.examples && lhs.readOnly == rhs.readOnly && lhs.writeOnly == rhs.writeOnly && lhs.deprecated == rhs.deprecated && lhs.comment == rhs.comment
  }
}

public struct AnnotationResults: Sendable {
  private var storage: [String: Sendable] = [:]

  public init() {}

  public subscript<Key: AnnotationKey>(_ keyPath: KeyPath<AnnotationKeys.Type, Key.Type>) -> Key.ValueType? {
    get {
      let key = AnnotationKeys.self[keyPath: keyPath]
      return storage[key.key] as? Key.ValueType
    }
    set {
      let key = AnnotationKeys.self[keyPath: keyPath]
      storage[key.key] = newValue
    }
  }
}

public enum AnnotationKeys {
  // MARK: Array related

  static let prefixItems = PrefixItemsKey.self
  static let items = ItemsKey.self
  static let contains = ContainsKey.self

  // MARK: Object related

  static let properties = PropertiesKey.self
  static let patternProperties = PatternPropertiesKey.self
  static let additionalProperties = AdditionalPropertiesKey.self
}

public protocol AnnotationKey {
  associatedtype ValueType: Sendable
  static var key: String { get }
}

public enum PrefixItemsKey: AnnotationKey, Sendable {
  public static let key = "prefixItems"
  public typealias ValueType = Self

  /// The largest index to which this keyword applied a subschema
  case largestIndex(Int)
  /// Applied when subschema applies to every index of the instance
  case everyIndex
}

public enum ItemsKey: AnnotationKey {
  public static let key = "items"

  /// True when keywords validates on all (after prefix items)
  public typealias ValueType = Bool
}

public enum ContainsKey: AnnotationKey, Sendable {
  public static let key = "contains"
  public typealias ValueType = Self

  /// Array of indicies to which the keyword validates
  case indicies([Int])
  /// Applied when subschema validates successfully when applied to every index of the instance
  case everyIndex
}

public enum PropertiesKey: AnnotationKey {
  public static let key = "properties"
  /// The set of instance property names matched by this keyword
  public typealias ValueType = Set<String>
}

public enum PatternPropertiesKey: AnnotationKey {
  public static let key = "patternProperties"
  /// The set of instance property names matched by this keyword
  public typealias ValueType = Set<String>
}

public enum AdditionalPropertiesKey: AnnotationKey {
  public static let key = "additionalProperties"
  /// Set of instance property names validated by the keyword's subschema
  public typealias ValueType = Set<String>
}
