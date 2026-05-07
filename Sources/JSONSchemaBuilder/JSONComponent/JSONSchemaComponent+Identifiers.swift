import JSONSchema
import OrderedCollections

extension JSONSchemaComponent {
  public func id(_ value: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Identifier.name] = .string(value)
    return copy
  }

  public func schema(_ uri: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.SchemaKeyword.name] = .string(uri)
    return copy
  }

  /// Sets the schema vocabulary mapping.
  ///
  /// - Parameter mapping: Vocabulary URIs to enable/disable. Pass a
  ///   dictionary literal (e.g.
  ///   `[Vocabularies.Core: true, Vocabularies.Applicator: true]`); the
  ///   declaration order is preserved on emission.
  /// - Returns: A copy of this component with the `$vocabulary` keyword set.
  public func vocabulary(_ mapping: KeyValuePairs<String, Bool>) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Vocabulary.name] = .object(
      OrderedDictionary(uniqueKeysWithValues: mapping.map { ($0.key, JSONValue.boolean($0.value)) })
    )
    return copy
  }

  public func anchor(_ name: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Anchor.name] = .string(name)
    return copy
  }

  public func dynamicAnchor(_ name: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.DynamicAnchor.name] = .string(name)
    return copy
  }

  public func dynamicRef(_ uri: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.DynamicReference.name] = .string(uri)
    return copy
  }

  public func ref(_ uri: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Reference.name] = .string(uri)
    return copy
  }

  public func recursiveAnchor(_ name: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.RecursiveAnchor.name] = .string(name)
    return copy
  }

  public func recursiveRef(_ uri: String) -> Self {
    var copy = self
    copy.schemaValue[Keywords.RecursiveReference.name] = .string(uri)
    return copy
  }
}
