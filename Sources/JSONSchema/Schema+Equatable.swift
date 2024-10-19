extension Schema {
  public static func == (lhs: Schema, rhs: Schema) -> Bool {
    switch (lhs.schema, rhs.schema) {
    case (let lhsBool as BooleanSchema, let rhsBool as BooleanSchema): return lhsBool == rhsBool
    case (let lhsObject as ObjectSchema, let rhsObject as ObjectSchema):
      return lhsObject == rhsObject
    default: return false
    }
  }
}

extension BooleanSchema {
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.schemaValue == rhs.schemaValue }
}

extension ObjectSchema {
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.schemaValue == rhs.schemaValue }
}
