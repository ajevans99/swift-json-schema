protocol ApplicatorKeyword: AnnotationProducingKeyword {
  func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue)
}

extension Keywords {
  struct Items: ApplicatorKeyword {
    static let name = "items"

    let schema: JSONValue
    let location: JSONPointer

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      if let rawSchemas = schema.array {
        var subschemas = [Schema]()
        subschemas.reserveCapacity(rawSchemas.count)
        for (index, rawSchema) in rawSchemas.enumerated() {
          let pointer = location.appending(.index(index))
          let subschema = try! Schema(rawSchema: rawSchema, location: pointer)
          subschemas.append(subschema)
        }
        self.subschemas = subschemas
      } else {
        subschemas = []
      }
    }

    typealias AnnotationValue = JSONValue // TODO

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      for (instance, schema) in zip(instances, subschemas) {
        let result = schema.validate(instance, at: location)
        if !result.valid {
          throw .invalidItem(result)
        }
      }
    }
  }

  struct Contains: ApplicatorKeyword {
    static let name = "contains"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      subschema = (try? Schema(rawSchema: schema, location: location)) ?? BooleanSchema(schemaValue: true, location: location).asSchema()
    }

    typealias AnnotationValue = ContainsAnnotationValue

    enum ContainsAnnotationValue: AnnotationValueConvertible {
      /// Array of indicies to which the keyword validates
      case indicies([Int])
      /// Applied when subschema validates successfully when applied to every index of the instance
      case everyIndex

      var value: JSONValue {
        switch self {
        case .indicies(let array):
          .array(array.map { .integer($0) })
        case .everyIndex:
          true
        }
      }
    }

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      var validIndices = [Int]()
      for (index, instance) in instances.enumerated() {
        let pointer = location.appending(.index(index))
        let result = subschema.validate(instance, at: pointer)
        if result.valid {
          validIndices.append(index)
        }
      }

      let annotationValue = validIndices.count == instances.count ? ContainsAnnotationValue.everyIndex : .indicies(validIndices)
      annotations[Self.self] = .init(
        keyword: self,
        instanceLocation: location,
        schemaLocation: self.location,
        absoluteSchemaLocation: nil, // TODO
        value: annotationValue
      )

      if validIndices.isEmpty {
        throw .containsInsufficientMatches
      }
    }
  }
}
