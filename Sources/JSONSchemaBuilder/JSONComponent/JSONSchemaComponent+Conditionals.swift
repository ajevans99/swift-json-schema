import JSONSchema

extension JSONSchemaComponent {
  /// Sets the ``Keywords/If`` subschema on the schema.
  ///
  /// Use this method to specify a condition that must hold for the ``then`` or
  /// ``else`` branches to apply.
  /// - Parameter schema: A builder that creates the conditional subschema.
  /// - Returns: A copy of this component with the ``if`` subschema set.
  public func `if`(@JSONSchemaBuilder _ schema: () -> some JSONSchemaComponent) -> Self {
    var copy = self
    copy.schemaValue[Keywords.If.name] = schema().schemaValue.value
    return copy
  }

  /// Sets the ``Keywords/Then`` subschema on the schema.
  ///
  /// The ``then`` subschema is applied when the ``if`` condition evaluates to
  /// `true`.
  /// - Parameter schema: A builder that creates the subschema to apply when the
  ///   condition matches.
  /// - Returns: A copy of this component with the ``then`` subschema set.
  public func then(@JSONSchemaBuilder _ schema: () -> some JSONSchemaComponent) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Then.name] = schema().schemaValue.value
    return copy
  }

  /// Sets the ``Keywords/Else`` subschema on the schema.
  ///
  /// The ``else`` subschema is applied when the ``if`` condition evaluates to
  /// `false`.
  /// - Parameter schema: A builder that creates the subschema to apply when the
  ///   condition does not match.
  /// - Returns: A copy of this component with the ``else`` subschema set.
  public func `else`(@JSONSchemaBuilder _ schema: () -> some JSONSchemaComponent) -> Self {
    var copy = self
    copy.schemaValue[Keywords.Else.name] = schema().schemaValue.value
    return copy
  }

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
