import JSONSchema

extension DefaultValidator {
  public func validate(array: [JSONValue], against options: ArraySchemaOptions) -> Validation<[JSONValue]> {
    let builder = ValidationErrorBuilder()

    let nonNegativeInteger = JSONInteger().minimum(0)

    validateOption(options.maxItems, schema: nonNegativeInteger, name: "maxItems", builder: builder) { maxItems in
      if array.count > maxItems {
        builder.addError(.array(issue: .maxItems(expected: maxItems), actual: array))
      }
    }

    validateOption(options.minItems, schema: nonNegativeInteger, name: "minItems", builder: builder) { minItems in
      if array.count < minItems {
        builder.addError(.array(issue: .minItems(expected: minItems), actual: array))
      }
    }

    validateOption(options.uniqueItems, schema: JSONBoolean(), name: "uniqueItems", builder: builder) { uniqueItems in
      guard uniqueItems else { return }

      var seenItems = Set<JSONValue>()
      var duplicates = [JSONValue]()

      for item in array {
        if !seenItems.insert(item).inserted {
          duplicates.append(item)
        }
      }

      if !duplicates.isEmpty {
        builder.addErrors(duplicates.map { .array(issue: .uniqueItems(duplicate: $0), actual: array) })
      }
    }

    return builder.build(for: array)
  }
}
