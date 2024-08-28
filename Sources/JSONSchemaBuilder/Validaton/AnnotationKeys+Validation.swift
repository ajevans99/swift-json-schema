import JSONSchema

extension AnnotationResults {
  // MARK: Array related

  static let prefixItems = PrefixItemsKey.self
  static let items = ItemsKey.self
  static let contains = ContainsKey.self

  // MARK: Object related

  static let properties = PropertiesKey.self
  static let patternProperties = PatternPropertiesKey.self
  static let additionalProperties = AdditionalPropertiesKey.self
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

