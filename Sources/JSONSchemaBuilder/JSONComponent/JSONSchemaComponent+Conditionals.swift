import JSONSchema
import OrderedCollections

extension JSONSchemaComponent {
  /// Sets the ``Keywords/DependentRequired`` mapping on the schema.
  ///
  /// When the specified key is present in the input, each of the associated
  /// property names must also be present.
  /// - Parameter mapping: A dictionary mapping property names to arrays of
  ///   required property names.
  /// - Returns: A copy of this component with the ``dependentRequired`` mapping
  ///   set.
  public func dependentRequired(_ mapping: [String: [String]]) -> Self {
    var copy = self
    // Sort keys so emission is deterministic regardless of the input
    // Dictionary's hash-seed-dependent iteration order.
    copy.schemaValue[Keywords.DependentRequired.name] = .object(
      OrderedDictionary(
        uniqueKeysWithValues: mapping.keys.sorted()
          .map { key in
            (key, JSONValue.array(mapping[key]!.map { .string($0) }))
          }
      )
    )
    return copy
  }

  /// Sets the ``Keywords/DependentSchemas`` mapping on the schema.
  ///
  /// The schemas in this mapping are evaluated when the corresponding property
  /// is present in the input.
  /// - Parameter mapping: A dictionary whose keys are property names and values
  ///   are the schemas to validate when that property exists.
  /// - Returns: A copy of this component with the ``dependentSchemas`` mapping
  ///   set.
  public func dependentSchemas(_ mapping: [String: any JSONSchemaComponent]) -> Self {
    var copy = self
    // Sort keys so emission is deterministic regardless of the input
    // Dictionary's hash-seed-dependent iteration order.
    copy.schemaValue[Keywords.DependentSchemas.name] = .object(
      OrderedDictionary(
        uniqueKeysWithValues: mapping.keys.sorted()
          .map { key in
            (key, mapping[key]!.schemaValue.value)
          }
      )
    )
    return copy
  }
}
