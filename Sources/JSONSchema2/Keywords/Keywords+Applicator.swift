protocol ApplicatorKeyword: AnnotationProducingKeyword {
  func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue)
}

// MARK: - Arrays

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-prefixitems
  struct PrefixItems: ApplicatorKeyword {
    static let name = "items"

    let schema: JSONValue
    let location: JSONPointer

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschemas = schema.array?.extractSubschemas(at: location) ?? []
    }

    typealias AnnotationValue = PrefixItemsAnnoationValue

    enum PrefixItemsAnnoationValue: AnnotationValueConvertible {
      /// The largest index to which this keyword applied a subschema
      case largestIndex(Int)
      /// Applied when subschema applies to every index of the instance
      case everyIndex

      var value: JSONValue {
        switch self {
        case .largestIndex(let int):
          return .integer(int)
        case .everyIndex:
          return true
        }
      }
    }

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      var largestIndex: Int = instances.startIndex
      for (offset, (instance, schema)) in zip(instances, subschemas).enumerated() {
        let location = location.appending(.index(offset))
        let result = schema.validate(instance, at: location)
        if !result.valid {
          throw .invalidItem(result)
        }
        largestIndex = offset
      }

      annotations[Self.self] = .init(
        keyword: self,
        instanceLocation: location,
        value: largestIndex == instances.endIndex ? .everyIndex : .largestIndex(largestIndex)
      )
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-items
  struct Items: ApplicatorKeyword {
    static let name = "items"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Bool

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      let relevantInstanceItems: ArraySlice<JSONValue> = switch annotations[PrefixItems.self]?.value {
        case .everyIndex: .init()
        case .largestIndex(let index): instances.dropFirst(index)
        case .none: instances[...]
        }
      for (index, instance) in zip(relevantInstanceItems.indices, relevantInstanceItems) {
        let location = location.appending(.index(index))
        let result = subschema.validate(instance, at: location)
        if !result.valid {
          throw .invalidItem(result)
        }
      }

      annotations[Self.self] = .init(
        keyword: self,
        instanceLocation: location,
        value: true
      )
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-contains
  struct Contains: ApplicatorKeyword {
    static let name = "contains"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
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
        value: annotationValue
      )

      if validIndices.isEmpty {
        throw .containsInsufficientMatches
      }
    }
  }
}

// MARK: - Objects

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-properties
  struct Properites: ApplicatorKeyword {
    static let name = "properties"

    let schema: JSONValue
    let location: JSONPointer

    private let schemaMap: [String: Schema]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      self.schemaMap = schema.object?.compactMapValues { rawSchema in
        try? Schema(rawSchema: rawSchema, location: location)
      } ?? [:]
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else {
        return
      }

      var instancePropertyNames: Set<String> = []

      for (key, value) in instanceObject where schemaMap.keys.contains(key) {
        let location = location.appending(.key(key))
        let result = schemaMap[key]!.validate(value, at: location)

        if !result.valid {
          throw .invalidProperty(result)
        }

        instancePropertyNames.insert(key)
      }

      annotations[Self.self] = .init(keyword: self, instanceLocation: location, value: instancePropertyNames)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-patternproperties
  struct PatternProperties: ApplicatorKeyword {
    static let name = "patternProperties"

    let schema: JSONValue
    let location: JSONPointer
    private let patterns: [(Regex<AnyRegexOutput>, Schema)]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      self.patterns = schema.object?.compactMap { key, rawSchema in
        guard let regex = try? Regex(key) else { return nil }
        guard let subschema = try? Schema(rawSchema: rawSchema, location: location) else { return nil }
        return (regex, subschema)
      } ?? []
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var matchedPropertyNames: Set<String> = []

      for (key, value) in instanceObject {
        for (regex, schema) in patterns {
          if key.wholeMatch(of: regex) != nil {
            let propertyLocation = location.appending(.key(key))
            let result = schema.validate(value, at: propertyLocation)

            if !result.valid {
              throw ValidationIssue.invalidPatternProperty(result)
            }

            matchedPropertyNames.insert(key)
          }
        }
      }

      annotations[Self.self] = .init(keyword: self, instanceLocation: location, value: matchedPropertyNames)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-additionalproperties
  struct AdditionalProperties: ApplicatorKeyword {
    static let name = "additionalProperties"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      let previouslyValidatedKeys = (annotations[AdditionalProperties.self]?.value ?? [])
        .union(annotations[PatternProperties.self]?.value ?? [])

      var validatedKeys: Set<String> = []

      for (key, value) in instanceObject where !previouslyValidatedKeys.contains(key) {
        let propertyLocation = location.appending(.key(key))
        let result = subschema.validate(value, at: propertyLocation)

        if !result.valid {
          throw ValidationIssue.invalidAdditionalProperty(result)
        }

        validatedKeys.insert(key)
      }

      annotations[Self.self] = .init(keyword: self, instanceLocation: location, value: validatedKeys)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-propertynames
  struct PropertyNames: ApplicatorKeyword {
    static let name = "propertyNames"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      for key in instanceObject.keys {
        let result = subschema.validate(.string(key), at: location) // TODO: Location?
        if !result.valid {
          throw .invalidPatternProperty(result)
        }
      }
    }
  }
}

// MARK: - In Place (Logic)

extension Keywords {
  struct AllOf: ApplicatorKeyword {
    static let name = "allOf"

    let schema: JSONValue
    let location: JSONPointer

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschemas = schema.array?.extractSubschemas(at: location) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }

  struct AnyOf: ApplicatorKeyword {
    static let name = "anyOf"

    let schema: JSONValue
    let location: JSONPointer

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschemas = schema.array?.extractSubschemas(at: location) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }

  struct OneOf: ApplicatorKeyword {
    static let name = "oneOf"

    let schema: JSONValue
    let location: JSONPointer

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschemas = schema.array?.extractSubschemas(at: location) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }

  struct Not: ApplicatorKeyword {
    static let name = "not"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }
}

// MARK: - In Place (Conditionally

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-if
  struct If: ApplicatorKeyword {
    static let name = "if"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Bool

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-then
  struct Then: ApplicatorKeyword {
    static let name = "then"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-else
  struct Else: ApplicatorKeyword {
    static let name = "else"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-dependentschemas
  struct DependentSchemas: ApplicatorKeyword {
    static let name = "dependentSchemas"

    let schema: JSONValue
    let location: JSONPointer

    private let schemaMap: [String: Schema]

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location

      self.schemaMap = schema.object?.compactMapValues { rawSchema in
        try? Schema(rawSchema: rawSchema, location: location)
      } ?? [:]
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }
}

// MARK: - Unevaluated Locations

extension Keywords {
  struct UnevaluatedItems: ApplicatorKeyword {
    static let name = "unevaluatedItems"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }

  struct UnevaluatedProperties: ApplicatorKeyword {
    static let name = "unevaluatedProperties"

    let schema: JSONValue
    let location: JSONPointer

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer) {
      self.schema = schema
      self.location = location
      self.subschema = schema.extractSubschema(at: location)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      // TODO
    }
  }
}

// MARK: - Helpers

extension Never: AnnotationValueConvertible {
  var value: JSONValue { .null }
}

extension Set: AnnotationValueConvertible where Element == String {
  var value: JSONSchema.JSONValue {
    .array(self.map { .string($0) })
  }
}

extension Bool: AnnotationValueConvertible {
  var value: JSONValue { .boolean(self) }
}

private extension Array where Element == JSONValue {
  func extractSubschemas(at location: JSONPointer) -> [Schema] {
    var subschemas = [Schema]()
    subschemas.reserveCapacity(self.count)
    for (index, rawSchema) in self.enumerated() {
      let pointer = location.appending(.index(index))
      // TODO: Warn on invalid schema?
      if let subschema = try? Schema(rawSchema: rawSchema, location: pointer) {
        subschemas.append(subschema)
      }
    }
    return subschemas
  }
}

private extension JSONValue {
  func extractSubschema(at location: JSONPointer) -> Schema {
    (try? Schema(rawSchema: self, location: location)) ?? BooleanSchema(schemaValue: true, location: location).asSchema()
  }
}
