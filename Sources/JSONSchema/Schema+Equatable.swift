extension Schema: Equatable {
  private static func areOptionsEqual<T: SchemaOptions & Equatable>(
    _ lhsOptions: AnySchemaOptions?,
    _ rhsOptions: AnySchemaOptions?,
    as type: T.Type
  ) -> Bool {
    guard let lhsTypedOptions = lhsOptions?.asType(type),
      let rhsTypedOptions = rhsOptions?.asType(type)
    else { return lhsOptions == nil && rhsOptions == nil }
    return lhsTypedOptions == rhsTypedOptions
  }

  public static func == (lhs: Schema, rhs: Schema) -> Bool {
    guard lhs.type == rhs.type else { return false }

    // FIXME: Is there a more elegant way to do this? Type erasure makes equatable difficult
    let areOptionsMatching =
      switch lhs.type {
      case .array: areOptionsEqual(lhs.options, rhs.options, as: ArraySchemaOptions.self)
      case .number: areOptionsEqual(lhs.options, rhs.options, as: NumberSchemaOptions.self)
      case .object: areOptionsEqual(lhs.options, rhs.options, as: ObjectSchemaOptions.self)
      case .string: areOptionsEqual(lhs.options, rhs.options, as: StringSchemaOptions.self)
      case .boolean, .integer, .null, .none: true
      }

    return lhs.type == rhs.type && lhs.annotations == rhs.annotations
      && lhs.enumValues == rhs.enumValues && lhs.composition == rhs.composition 
      && areOptionsMatching
  }
}
