import JSONSchema

extension DefaultValidator {
  public func validate(object: [String: JSONValue], against options: ObjectSchemaOptions) -> Validation<[String: JSONValue]> {
    let builder = ValidationErrorBuilder()

    let nonNegativeInteger = JSONInteger().minimum(0)

    validateOption(options.maxProperties, schema: nonNegativeInteger, name: "maxProperties", builder: builder) { maxProperties in
      if object.keys.count > maxProperties {
        builder.addError(.object(issue: .maxProperties(expected: maxProperties), actual: object))
      }
    }

    validateOption(options.minProperties, schema: nonNegativeInteger, name: "minProperties", builder: builder) { minProperties in
      if object.keys.count < minProperties {
        builder.addError(.object(issue: .minProperties(expected: minProperties), actual: object))
      }
    }

    let requiredSchema = JSONArray {
      JSONString()
    }
    .uniqueItems()

    validateOption(options.required, schema: requiredSchema, name: "required", builder: builder) { required in
      for key in required {
        if !object.keys.contains(key) {
          builder.addError(.object(issue: .required(key: key), actual: object))
        }
      }
    }

    let dependentRequiredSchema = JSONObject()
      .additionalProperties {
        JSONArray {
          JSONString()
        }
      }
      .map(\.1)

    validateOption(options.dependentRequired, schema: dependentRequiredSchema, name: "dependentRequired", builder: builder) { dependencies in
      for (property, requiredProperties) in dependencies {
        if object.keys.contains(property) {
          for requiredProperty in requiredProperties {
            if !object.keys.contains(requiredProperty) {
              builder.addError(.object(issue: .dependentRequired(mainProperty: property, dependentProperty: requiredProperty), actual: object))
            }
          }
        }
      }
    }

    return builder.build(for: object)
  }
}
