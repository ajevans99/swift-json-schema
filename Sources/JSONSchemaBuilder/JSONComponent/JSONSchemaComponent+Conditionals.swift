import JSONSchema

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
    copy.schemaValue[Keywords.DependentRequired.name] = .object(
      Dictionary(
        uniqueKeysWithValues: mapping.map { key, array in
          (key, .array(array.map { .string($0) }))
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
    copy.schemaValue[Keywords.DependentSchemas.name] = .object(
      Dictionary(
        uniqueKeysWithValues: mapping.map { key, component in
          (key, component.schemaValue.value)
        }
      )
    )
    return copy
  }
}
