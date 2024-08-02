import JSONSchema

public struct SchemaValidator {
  let schema: Schema

  public init(schema: Schema) {
    self.schema = schema
  }

//  public func validate(data: JSONValue) -> SchemaValidationResult {
//    validate(data: data, against: schema)
//  }

//  private func validate<T>(data: JSONValue, against schema: Schema) -> Validated<T, SchemaValidationError> {
//    var errors: [SchemaValidationError]
//
//    try validateType(of: data, against: schema)
//
//    // Type specific validation
//    switch data {
//    case .object(let object):
//      try validate(object: object, against: schema)
//    case .array(let array):
//      try validate(array: array, against: schema)
//    case .string(let string):
//      try validate(string: string, against: schema)
//    default:
//      break
//    }
//  }
}

//extension SchemaValidator {
//  private func validate(object: [String: JSONValue], against schema: Schema) -> Validated<T, SchemaValidationError> {
//    guard let options = schema.options?.asType(ObjectSchemaOptions.self) else {
//      if schema.options != nil {
//        throw SchemaValidationError.validationError("Unexpected options for object type")
//        return .error(SchemaValidationError)
//      }
//      return .valid(<#T##Void#>)
//    }
//
//    // Required properties
//    if let required = options.required {
//      for property in required where object.keys.contains(property) {
//        throw SchemaValidationError.objectError(.missingRequiredProperty(property))
//      }
//
//      // Check for unique required keys
//      let uniqueRequired = Set(required)
//      if uniqueRequired.count != required.count {
//        throw SchemaValidationError.objectError(.duplicateKeysInRequiredProperty(required))
//      }
//    }
//
//    // Property validation
//    if let properties = options.properties {
//      for (property, propertySchema) in properties {
//        if let value = object[property] {
//          try validate(data: value, against: propertySchema)
//        }
//      }
//    }
//
//    // Additional properties
//    if let additionalProperties = options.additionalProperties {
//      switch additionalProperties {
//      case .schema(let schema):
//        break
//      case .disabled:
//        let definedKeys = options.properties?.keys
//        let extraKeys = object.keys.filter { definedKeys?.contains($0) == false }
//        if !extraKeys.isEmpty {
//          throw SchemaValidationError.objectError(.additionalPropertiesFound(extraKeys))
//        }
//      }
//    }
//  }
//
//  private func validate(array: [JSONValue], against schema: Schema) -> SchemaValidationResult {
//    guard let options = schema.options?.asType(ArraySchemaOptions.self) else {
//      if schema.options != nil {
//        throw SchemaValidationError.validationError("Unexpected options for array type")
//      }
//      return
//    }
//
//    if let items = options.items {
//      switch items {
//      case .schema(let schema):
//        for item in array {
//          try validate(data: item, against: schema)
//        }
//      case .disabled:
//        // Prevent array elements beyond what are provided in prefix items
//        break
//      }
//    }
//  }
//
//  private func validate(string: String, against schema: Schema) -> Validated<String, SchemaValidationError> {
//    .valid(string)
//  }
//
//  private func validate(number: Double, against schema: Schema) -> Validated<Double, SchemaValidationError> {
//    .valid(number)
//  }
//
//  private func validate(integer: Int, against schema: Schema) -> Validated<Int, SchemaValidationError> {
//    .valid(integer)
//  }
//
//  private func validate(boolean: Bool, against schema: Schema) -> Validated<Bool, SchemaValidationError> {
//    .valid(boolean)
//  }
//
//  private func validateType(of value: JSONValue, against schema: Schema) -> Validated<Void, SchemaValidationError> {
//    if let type = schema.type, value.type != type {
//      return .error(SchemaValidationError.typeMismatch(expected: type, found: value))
//    }
//    return .valid(())
//  }
//}
