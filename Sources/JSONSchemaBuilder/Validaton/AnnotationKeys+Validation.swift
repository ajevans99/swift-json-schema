import JSONSchema

extension AnnotationResults {
  // MARK: Array related

  public var prefixItems: PrefixItemsKey.ValueType? {
    get { self[PrefixItemsKey.self] }
    set { self[PrefixItemsKey.self] = newValue }
  }

  public var items: ItemsKey.ValueType? {
    get { self[ItemsKey.self] }
    set { self[ItemsKey.self] = newValue }
  }

  public var contains: ContainsKey.ValueType? {
    get { self[ContainsKey.self] }
    set { self[ContainsKey.self] = newValue }
  }

  // MARK: Object related

  public var properties: PropertiesKey.ValueType? {
    get { self[PropertiesKey.self] }
    set { self[PropertiesKey.self] = newValue }
  }

  public var patternProperties: PatternPropertiesKey.ValueType? {
    get { self[PatternPropertiesKey.self] }
    set { self[PatternPropertiesKey.self] = newValue }
  }

  public var additionalProperties: AdditionalPropertiesKey.ValueType? {
    get { self[AdditionalPropertiesKey.self] }
    set { self[AdditionalPropertiesKey.self] = newValue }
  }
}

public enum PrefixItemsKey: AnnotationKey, Sendable {
  public typealias ValueType = Self

  /// The largest index to which this keyword applied a subschema
  case largestIndex(Int)
  /// Applied when subschema applies to every index of the instance
  case everyIndex
}

public enum ItemsKey: AnnotationKey {
  /// True when keywords validates on all (after prefix items)
  public typealias ValueType = Bool
}

public enum ContainsKey: AnnotationKey, Sendable {
  public typealias ValueType = Self

  /// Array of indicies to which the keyword validates
  case indicies([Int])
  /// Applied when subschema validates successfully when applied to every index of the instance
  case everyIndex
}

public enum PropertiesKey: AnnotationKey {
  /// The set of instance property names matched by this keyword
  public typealias ValueType = Set<String>
}

public enum PatternPropertiesKey: AnnotationKey {
  /// The set of instance property names matched by this keyword
  public typealias ValueType = Set<String>
}

public enum AdditionalPropertiesKey: AnnotationKey {
  /// Set of instance property names validated by the keyword's subschema
  public typealias ValueType = Set<String>
}
