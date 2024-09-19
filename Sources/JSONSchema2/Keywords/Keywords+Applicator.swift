protocol ApplicatorKeyword: AnnotationProducingKeyword {
  func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue)
}

// MARK: - Arrays

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-prefixitems
  struct PrefixItems: ApplicatorKeyword {
    static let name = "prefixItems"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschemas = schema.array?.extractSubschemas(at: location, with: context) ?? []
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
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for (offset, (instance, schema)) in zip(instances, subschemas).enumerated() {
        let location = location.appending(.index(offset))
        let result = schema.validate(instance, at: location)
        builder.merging(result)
        largestIndex = offset
      }

      try builder.throwIfErrors()

      annotations.insert(
        keyword: self,
        at: location,
        value: largestIndex == instances.indices.last ? .everyIndex : .largestIndex(largestIndex)
      )
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-items
  struct Items: ApplicatorKeyword {
    static let name = "items"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Bool

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      let prefixItemsAnnotation = annotations.annotation(for: PrefixItems.self, at: location)
      let relevantInstanceItems: ArraySlice<JSONValue> = switch prefixItemsAnnotation?.value {
      case .everyIndex: .init()
      case .largestIndex(let index): instances.dropFirst(index + 1)
      case .none: instances[...]
      }

      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      // With array slice, original array indicies are used which is important here.
      for (index, instance) in zip(relevantInstanceItems.indices, relevantInstanceItems) {
        let location = location.appending(.index(index))
        let result = subschema.validate(instance, at: location)
        builder.merging(result)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: location, value: true)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-contains
  struct Contains: ApplicatorKeyword {
    static let name = "contains"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
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

      if validIndices.isEmpty && !context.minContainsIsZero {
        throw .containsInsufficientMatches
      }

      let annotationValue = validIndices.count == instances.count ? ContainsAnnotationValue.everyIndex : .indicies(validIndices)
      annotations.insert(keyword: self, at: location, value: annotationValue)
    }
  }
}

// MARK: - Objects

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-properties
  struct Properties: ApplicatorKeyword {
    static let name = "properties"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let schemaMap: [String: Schema]

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context

      self.schemaMap = schema.object?.reduce(into: [:]) { result, keyValue in
        let (key, rawSchema) = keyValue
        let updatedLocation = location.appending(.key(key))
        if let schema = try? Schema(rawSchema: rawSchema, location: updatedLocation, context: context) {
          result[key] = schema
        }
      } ?? [:]
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else {
        return
      }

      var instancePropertyNames: Set<String> = []
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for (key, value) in instanceObject where schemaMap.keys.contains(key) {
        let propertyLocation = location.appending(.key(key))
        let result = schemaMap[key]!.validate(value, at: propertyLocation)
        builder.merging(result)
        instancePropertyNames.insert(key)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: location, value: instancePropertyNames)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-patternproperties
  struct PatternProperties: ApplicatorKeyword {
    static let name = "patternProperties"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context
    private let patterns: [(Regex<AnyRegexOutput>, Schema)]

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context

      self.patterns = schema.object?.compactMap { key, rawSchema in
        guard let regex = try? Regex(key) else { return nil }
        guard let subschema = try? Schema(rawSchema: rawSchema, location: location.appending(.key(key)), context: context) else { return nil }
        return (regex, subschema)
      } ?? []
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var matchedPropertyNames: Set<String> = []
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for (key, value) in instanceObject {
        for (regex, schema) in patterns {
          if key.firstMatch(of: regex) != nil {
            let propertyLocation = location.appending(.key(key))
            let result = schema.validate(value, at: propertyLocation)
            builder.merging(result)
            matchedPropertyNames.insert(key)
          }
        }
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: location, value: matchedPropertyNames)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-additionalproperties
  struct AdditionalProperties: ApplicatorKeyword {
    static let name = "additionalProperties"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      let previouslyValidatedKeys = (annotations.annotation(for: Properties.self, at: location)?.value ?? [])
        .union(annotations.annotation(for: PatternProperties.self, at: location)?.value ?? [])

      var validatedKeys: Set<String> = []
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for (key, value) in instanceObject where !previouslyValidatedKeys.contains(key) {
        let propertyLocation = location.appending(.key(key))
        let result = subschema.validate(value, at: propertyLocation)
        builder.merging(result)
        validatedKeys.insert(key)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: location, value: validatedKeys)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-propertynames
  struct PropertyNames: ApplicatorKeyword {
    static let name = "propertyNames"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for key in instanceObject.keys {
        let keyValue = JSONValue.string(key)
        let result = subschema.validate(keyValue, at: location.appending(.key(key)))
        builder.merging(result)
      }

      try builder.throwIfErrors()
    }
  }
}

// MARK: - In Place (Logic)

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-allof
  struct AllOf: ApplicatorKeyword {
    static let name = "allOf"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschemas = schema.array?.extractSubschemas(at: location, with: context) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for subschema in subschemas {
        let result = subschema.validate(input, at: location)
        builder.merging(result)
      }

      try builder.throwIfErrors()
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-anyof
  struct AnyOf: ApplicatorKeyword {
    static let name = "anyOf"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschemas = schema.array?.extractSubschemas(at: location, with: context) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var isValid = false
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for subschema in subschemas {
        let result = subschema.validate(input, at: location)
        if result.valid {
          isValid = true
          break
        }
        builder.merging(result)
      }

      if !isValid {
        try builder.throwIfErrors()
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-oneof
  struct OneOf: ApplicatorKeyword {
    static let name = "oneOf"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschemas: [Schema]

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschemas = schema.array?.extractSubschemas(at: location, with: context) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var validCount = 0
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for subschema in subschemas {
        let result = subschema.validate(input, at: location)
        if result.valid {
          validCount += 1
        }
        builder.merging(result)
      }

      if validCount != 1 {
        throw ValidationIssue.oneOfFailed
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#section-10.2.1.4
  struct Not: ApplicatorKeyword {
    static let name = "not"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      let result = subschema.validate(input, at: location)
      if result.valid {
        throw ValidationIssue.notFailed
      }
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
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      let result = subschema.validate(input, at: location)
      context.ifConditionalResult = result
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-then
  struct Then: ApplicatorKeyword {
    static let name = "then"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      if context.ifConditionalResult?.valid == true {
        let result = subschema.validate(input, at: location)
        if !result.valid {
          throw .conditionalFailed
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-else
  struct Else: ApplicatorKeyword {
    static let name = "else"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      if context.ifConditionalResult?.valid == false {
        let result = subschema.validate(input, at: location)
        if !result.valid {
          throw .conditionalFailed
        }
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-dependentschemas
  struct DependentSchemas: ApplicatorKeyword {
    static let name = "dependentSchemas"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let schemaMap: [String: Schema]

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context

      self.schemaMap = schema.object?.compactMapValues { rawSchema in
        try? Schema(rawSchema: rawSchema, location: location, context: context)
      } ?? [:]
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for (key, schema) in schemaMap {
        if instanceObject.keys.contains(key) {
          let propertyLocation = location.appending(.key(key))
          let result = schema.validate(input, at: propertyLocation)
          builder.merging(result)
        }
      }

      try builder.throwIfErrors()
    }
  }
}

// MARK: - Unevaluated Locations

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-unevaluateditems
  struct UnevaluatedItems: ApplicatorKeyword {
    static let name = "unevaluatedItems"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Bool

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      var evaluatedIndices = Set<Int>()

      if let prefixItemsAnnotation = annotations.annotation(for: PrefixItems.self, at: location)?.value {
        switch prefixItemsAnnotation {
        case .everyIndex:
          return
        case .largestIndex(let largestIndex):
          evaluatedIndices.formUnion(0...largestIndex)
        }
      }

      if let itemsAnnotation = annotations.annotation(for: Items.self, at: location)?.value, itemsAnnotation == true {
        evaluatedIndices.formUnion(0..<instances.count)
      }

      if let containsAnnotation = annotations.annotation(for: Contains.self, at: location)?.value {
        switch containsAnnotation {
        case .everyIndex:
          evaluatedIndices.formUnion(0..<instances.count)
        case .indicies(let indicies):
          evaluatedIndices.formUnion(indicies)
        }
      }

      let unevaluatedIndices = Set(instances.indices).subtracting(evaluatedIndices)
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)

      for index in unevaluatedIndices {
        let instance = instances[index]
        let itemLocation = location.appending(.index(index))
        let result = subschema.validate(instance, at: itemLocation)
        builder.merging(result)
      }

      try builder.throwIfErrors()

      if !unevaluatedIndices.isEmpty {
        annotations.insert(keyword: self, at: location, value: true)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-unevaluatedproperties
  struct UnevaluatedProperties: ApplicatorKeyword {
    static let name = "unevaluatedProperties"

    let schema: JSONValue
    let location: JSONPointer
    let context: Context

    private let subschema: Schema

    init(schema: JSONValue, location: JSONPointer, context: Context) {
      self.schema = schema
      self.location = location
      self.context = context
      self.subschema = schema.extractSubschema(at: location, with: context)
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at location: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var evaluatedPropertyNames = Set<String>()

      if let propertiesAnnotation = annotations.annotation(for: Properties.self, at: location)?.value {
        evaluatedPropertyNames.formUnion(propertiesAnnotation)
      }

      if let patternPropertiesAnnotation = annotations.annotation(for: PatternProperties.self, at: location)?.value {
        evaluatedPropertyNames.formUnion(patternPropertiesAnnotation)
      }

      if let additionalPropertiesAnnotation = annotations.annotation(for: AdditionalProperties.self, at: location)?.value {
        evaluatedPropertyNames.formUnion(additionalPropertiesAnnotation)
      }

      let unevaluatedPropertyNames = Set(instanceObject.keys).subtracting(evaluatedPropertyNames)
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: location)
      var validatedPropertyNames = Set<String>()

      for propertyName in unevaluatedPropertyNames {
        guard let propertyValue = instanceObject[propertyName] else { continue }
        let propertyLocation = location.appending(.key(propertyName))
        let result = subschema.validate(propertyValue, at: propertyLocation)
        builder.merging(result)
        validatedPropertyNames.insert(propertyName)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: location, value: validatedPropertyNames)
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
  func extractSubschemas(at location: JSONPointer, with context: Context) -> [Schema] {
    var subschemas = [Schema]()
    subschemas.reserveCapacity(self.count)
    for (index, rawSchema) in self.enumerated() {
      let pointer = location.appending(.index(index))
      // TODO: Warn on invalid schema?
      if let subschema = try? Schema(rawSchema: rawSchema, location: pointer, context: context) {
        subschemas.append(subschema)
      }
    }
    return subschemas
  }
}

private extension JSONValue {
  func extractSubschema(at location: JSONPointer, with context: Context) -> Schema {
    (try? Schema(rawSchema: self, location: location, context: context)) ?? BooleanSchema(schemaValue: true, location: location, context: context).asSchema()
  }
}

struct ValidationResultBuilder {
  let keyword: any Keyword
  let instanceLocation: JSONPointer

  init(keyword: any Keyword, instanceLocation: JSONPointer) {
    self.keyword = keyword
    self.instanceLocation = instanceLocation
  }

  private var errors: [ValidationError] = []

  mutating func merging(_ result: ValidationResult) {
    if !result.valid {
      if let resultErrors = result.errors {
        errors.append(contentsOf: resultErrors)
      }
      else {
        errors.append(
          .init(
            keyword: type(of: keyword).name,
            message: "Validation failed",
            keywordLocation: keyword.location,
            instanceLocation: instanceLocation
          )
        )
      }
    }
  }

  func throwIfErrors() throws(ValidationIssue) {
    if !errors.isEmpty {
      throw .keywordFailure(keyword: type(of: keyword).name, errors: errors)
    }
  }
}
