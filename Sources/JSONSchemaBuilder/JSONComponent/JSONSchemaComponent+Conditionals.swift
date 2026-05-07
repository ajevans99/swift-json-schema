import JSONSchema
import OrderedCollections

extension JSONSchemaComponent {
  /// Sets the ``Keywords/DependentRequired`` mapping on the schema.
  ///
  /// When the specified key is present in the input, each of the associated
  /// property names must also be present.
  /// - Parameter mapping: Property names to required-property arrays. Pass
  ///   a dictionary literal; the declaration order is preserved on emission.
  /// - Returns: A copy of this component with the ``dependentRequired`` mapping
  ///   set.
  public func dependentRequired(_ mapping: KeyValuePairs<String, [String]>) -> Self {
    var copy = self
    copy.schemaValue[Keywords.DependentRequired.name] = .object(
      OrderedDictionary(
        uniqueKeysWithValues: mapping.map { (key, array) in
          (key, JSONValue.array(array.map { .string($0) }))
        }
      )
    )
    return copy
  }

  /// Sets the ``Keywords/DependentSchemas`` mapping on the schema.
  ///
  /// The schemas in this mapping are evaluated when the corresponding property
  /// is present in the input.
  /// - Parameter mapping: Property names to schemas to validate when that
  ///   property exists. Pass a dictionary literal; the declaration order is
  ///   preserved on emission.
  /// - Returns: A copy of this component with the ``dependentSchemas`` mapping
  ///   set.
  public func dependentSchemas(_ mapping: KeyValuePairs<String, any JSONSchemaComponent>) -> Self {
    var copy = self
    copy.schemaValue[Keywords.DependentSchemas.name] = .object(
      OrderedDictionary(
        uniqueKeysWithValues: mapping.map { (key, component) in
          (key, component.schemaValue.value)
        }
      )
    )
    return copy
  }
}
