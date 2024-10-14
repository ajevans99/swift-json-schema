protocol ApplicatorKeyword: AnnotationProducingKeyword {
  func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue)
}

// MARK: - Arrays

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-prefixitems
  struct PrefixItems: ApplicatorKeyword {
    static let name = "prefixItems"

    let value: JSONValue
    let context: KeywordContext

    private let subschemas: [Schema]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschemas = value.array?.extractSubschemas(using: context) ?? []
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

      func merged(with other: PrefixItemsAnnoationValue) -> PrefixItemsAnnoationValue {
        switch (self, other) {
        case (.everyIndex, _):
          .everyIndex
        case (_, .everyIndex):
          .everyIndex
        case let (.largestIndex(lhs), .largestIndex(rhs)):
          .largestIndex(lhs > rhs ? lhs : rhs)
        }
      }
    }

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      var largestIndex: Int = instances.startIndex
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for (offset, (instance, schema)) in zip(instances, subschemas).enumerated() {
        let prefixLocation = instanceLocation.appending(.index(offset))
        let result = schema.validate(instance, at: prefixLocation)
        builder.merging(result)
        largestIndex = offset
      }

      try builder.throwIfErrors()

      annotations.insert(
        keyword: self,
        at: instanceLocation,
        value: largestIndex == instances.indices.last ? .everyIndex : .largestIndex(largestIndex)
      )
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-items
  struct Items: ApplicatorKeyword {
    static let name = "items"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Bool

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      let prefixItemsAnnotation = annotations.annotation(for: PrefixItems.self, at: instanceLocation)
      let relevantInstanceItems: ArraySlice<JSONValue> = switch prefixItemsAnnotation?.value {
      case .everyIndex: .init()
      case .largestIndex(let index): instances.dropFirst(index + 1)
      case .none: instances[...]
      }

      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      // With array slice, original array indicies are used which is important here.
      for (index, instance) in zip(relevantInstanceItems.indices, relevantInstanceItems) {
        let itemLocation = instanceLocation.appending(.index(index))
        let result = subschema.validate(instance, at: itemLocation)
        builder.merging(result)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: instanceLocation, value: true)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-contains
  struct Contains: ApplicatorKeyword {
    static let name = "contains"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
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

      func merged(with other: ContainsAnnotationValue) -> ContainsAnnotationValue {
        switch (self, other) {
        case (.indicies(let lhs), .indicies(let rhs)):
          .indicies(lhs + rhs)
        case (.everyIndex, _), (_, .everyIndex):
          .everyIndex
        }
      }
    }

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      var validIndices = [Int]()
      for (index, instance) in instances.enumerated() {
        let pointer = instanceLocation.appending(.index(index))
        let result = subschema.validate(instance, at: pointer)
        if result.valid {
          validIndices.append(index)
        }
      }

      if validIndices.isEmpty && !context.minContainsIsZero {
        throw .containsInsufficientMatches
      }

      let annotationValue = validIndices.count == instances.count ? ContainsAnnotationValue.everyIndex : .indicies(validIndices)
      annotations.insert(keyword: self, at: instanceLocation, value: annotationValue)
    }
  }
}

// MARK: - Objects

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-properties
  struct Properties: ApplicatorKeyword {
    static let name = "properties"

    let value: JSONValue
    let context: KeywordContext

    private let schemaMap: [String: Schema]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      self.schemaMap = value.object?.reduce(into: [:]) { result, keyValue in
        let (key, rawSchema) = keyValue
        let updatedLocation = context.location.appending(.key(key))
        if let schema = try? Schema(rawSchema: rawSchema, location: updatedLocation, context: context.context, baseURI: context.uri) {
          result[key] = schema
        }
      } ?? [:]
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else {
        return
      }

      var instancePropertyNames: Set<String> = []
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for (key, value) in instanceObject where schemaMap.keys.contains(key) {
        let propertyLocation = instanceLocation.appending(.key(key))
        var subAnnotations = AnnotationContainer()
        let result = schemaMap[key]!.validate(value, at: propertyLocation, annotations: &subAnnotations)
        builder.merging(result)
        annotations.merge(subAnnotations)
        instancePropertyNames.insert(key)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: instanceLocation, value: instancePropertyNames)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-patternproperties
  struct PatternProperties: ApplicatorKeyword {
    static let name = "patternProperties"

    let value: JSONValue
    let context: KeywordContext
    private let patterns: [(Regex<AnyRegexOutput>, Schema)]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      self.patterns = value.object?.compactMap { key, rawSchema in
        guard let regex = try? Regex(key) else { return nil }
        guard let subschema = try? Schema(rawSchema: rawSchema, location: context.location.appending(.key(key)), context: context.context, baseURI: context.uri) else { return nil }
        return (regex, subschema)
      } ?? []
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var matchedPropertyNames: Set<String> = []
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for (key, value) in instanceObject {
        for (regex, schema) in patterns {
          if key.firstMatch(of: regex) != nil {
            let propertyLocation = instanceLocation.appending(.key(key))
            let result = schema.validate(value, at: propertyLocation)
            builder.merging(result)
            matchedPropertyNames.insert(key)
          }
        }
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: instanceLocation, value: matchedPropertyNames)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-additionalproperties
  struct AdditionalProperties: ApplicatorKeyword {
    static let name = "additionalProperties"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      let previouslyValidatedKeys = (annotations.annotation(for: Properties.self, at: instanceLocation)?.value ?? [])
        .union(annotations.annotation(for: PatternProperties.self, at: instanceLocation)?.value ?? [])

      var validatedKeys: Set<String> = []
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for (key, value) in instanceObject where !previouslyValidatedKeys.contains(key) {
        let propertyLocation = instanceLocation.appending(.key(key))
        let result = subschema.validate(value, at: propertyLocation)
        builder.merging(result)
        validatedKeys.insert(key)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: instanceLocation, value: validatedKeys)
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-propertynames
  struct PropertyNames: ApplicatorKeyword {
    static let name = "propertyNames"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for key in instanceObject.keys {
        let keyValue = JSONValue.string(key)
        let result = subschema.validate(keyValue, at: instanceLocation.appending(.key(key)))
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

    let value: JSONValue
    let context: KeywordContext

    private let subschemas: [Schema]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschemas = value.array?.extractSubschemas(using: context) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for subschema in subschemas {
        var subAnnotations = AnnotationContainer()
        let result = subschema.validate(input, at: instanceLocation, annotations: &subAnnotations)
        annotations.merge(subAnnotations)
        builder.merging(result)
      }

      try builder.throwIfErrors()
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-anyof
  struct AnyOf: ApplicatorKeyword {
    static let name = "anyOf"

    let value: JSONValue
    let context: KeywordContext

    private let subschemas: [Schema]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschemas = value.array?.extractSubschemas(using: context) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var isValid = false
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for subschema in subschemas {
        var subAnnotations = AnnotationContainer()
        let result = subschema.validate(input, at: instanceLocation, annotations: &subAnnotations)
        if result.valid {
          isValid = true
        }
        annotations.merge(subAnnotations)
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

    let value: JSONValue
    let context: KeywordContext

    private let subschemas: [Schema]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschemas = value.array?.extractSubschemas(using: context) ?? []
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var validCount = 0
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for subschema in subschemas {
        var subAnnotations = AnnotationContainer()
        let result = subschema.validate(input, at: instanceLocation, annotations: &subAnnotations)
        if result.valid {
          validCount += 1
          annotations.merge(subAnnotations)
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

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var subAnnotations = AnnotationContainer()
      let result = subschema.validate(input, at: instanceLocation, annotations: &subAnnotations)
      if result.valid {
        annotations.merge(subAnnotations)
        throw ValidationIssue.notFailed
      }
    }
  }
}

// MARK: - In Place (Conditionally)

extension Keywords {
  /// https://json-schema.org/draft/2020-12/json-schema-core#name-if
  struct If: ApplicatorKeyword {
    static let name = "if"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      var subAnnotations = AnnotationContainer()
      let result = subschema.validate(input, at: instanceLocation, annotations: &subAnnotations)
      annotations.merge(subAnnotations)
      context.ifConditionalResult = result
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-then
  struct Then: ApplicatorKeyword {
    static let name = "then"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      if context.ifConditionalResult?.valid == true {
        var subAnnotations = AnnotationContainer()
        let result = subschema.validate(input, at: instanceLocation, annotations: &subAnnotations)
        if !result.valid {
          throw .conditionalFailed
        }
        annotations.merge(subAnnotations)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-else
  struct Else: ApplicatorKeyword {
    static let name = "else"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      if context.ifConditionalResult?.valid == false {
        var subAnnotations = AnnotationContainer()
        let result = subschema.validate(input, at: instanceLocation, annotations: &subAnnotations)
        if !result.valid {
          throw .conditionalFailed
        }
        annotations.merge(subAnnotations)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-dependentschemas
  struct DependentSchemas: ApplicatorKeyword {
    static let name = "dependentSchemas"

    let value: JSONValue
    let context: KeywordContext

    private let schemaMap: [String: Schema]

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context

      self.schemaMap = value.object?.compactMapValues { rawSchema in
        try? Schema(rawSchema: rawSchema, location: context.location, context: context.context)
      } ?? [:]
    }

    typealias AnnotationValue = Never

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else { return }

      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for (key, schema) in schemaMap {
        if instanceObject.keys.contains(key) {
          var subAnnotations = AnnotationContainer()
          let result = schema.validate(input, at: instanceLocation, annotations: &subAnnotations)
          builder.merging(result)
          annotations.merge(subAnnotations)
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

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Bool

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instances = input.array else { return }

      // Nested unevaluatedItems take precedence.
      // See "unevaluatedItems with nested unevaluatedItems" from JSON schema test suite.
      guard annotations.annotation(for: Self.self, at: instanceLocation) == nil else { return }

      var evaluatedIndices = Set<Int>()

      if let prefixItemsAnnotation = annotations.annotation(for: PrefixItems.self, at: instanceLocation)?.value {
        switch prefixItemsAnnotation {
        case .everyIndex:
          return
        case .largestIndex(let largestIndex):
          evaluatedIndices.formUnion(0...largestIndex)
        }
      }

      if let itemsAnnotation = annotations.annotation(for: Items.self, at: instanceLocation)?.value, itemsAnnotation == true {
        evaluatedIndices.formUnion(0..<instances.count)
      }

      if let containsAnnotation = annotations.annotation(for: Contains.self, at: instanceLocation)?.value {
        switch containsAnnotation {
        case .everyIndex:
          evaluatedIndices.formUnion(0..<instances.count)
        case .indicies(let indicies):
          evaluatedIndices.formUnion(indicies)
        }
      }

      let unevaluatedIndices = Set(instances.indices).subtracting(evaluatedIndices)
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)

      for index in unevaluatedIndices {
        let instance = instances[index]
        let itemLocation = instanceLocation.appending(.index(index))
        var subAnnotations = AnnotationContainer()
        let result = subschema.validate(instance, at: itemLocation, annotations: &subAnnotations)
        builder.merging(result)
        annotations.merge(subAnnotations)
      }

      try builder.throwIfErrors()

      if !unevaluatedIndices.isEmpty {
        annotations.insert(keyword: self, at: instanceLocation, value: true)
      }
    }
  }

  /// https://json-schema.org/draft/2020-12/json-schema-core#name-unevaluatedproperties
  struct UnevaluatedProperties: ApplicatorKeyword {
    static let name = "unevaluatedProperties"

    let value: JSONValue
    let context: KeywordContext

    private let subschema: Schema

    init(value: JSONValue, context: KeywordContext) {
      self.value = value
      self.context = context
      self.subschema = value.extractSubschema(using: context)
    }

    typealias AnnotationValue = Set<String>

    func validate(_ input: JSONValue, at instanceLocation: JSONPointer, using annotations: inout AnnotationContainer, with context: Context) throws(ValidationIssue) {
      guard let instanceObject = input.object else  { return }

      // Nested unevaluatedProperties take precedence.
      // See "unevaluatedProperties with nested unevaluatedProperties" from JSON schema test suite.
      guard annotations.annotation(for: Self.self, at: instanceLocation) == nil else { return }

      var evaluatedPropertyNames = Set<String>()

      if let propertiesAnnotation = annotations.annotation(for: Properties.self, at: instanceLocation)?.value {
        evaluatedPropertyNames.formUnion(propertiesAnnotation)
      }

      if let patternPropertiesAnnotation = annotations.annotation(for: PatternProperties.self, at: instanceLocation)?.value {
        evaluatedPropertyNames.formUnion(patternPropertiesAnnotation)
      }

      if let additionalPropertiesAnnotation = annotations.annotation(for: AdditionalProperties.self, at: instanceLocation)?.value {
        evaluatedPropertyNames.formUnion(additionalPropertiesAnnotation)
      }

      let unevaluatedPropertyNames = Set(instanceObject.keys).subtracting(evaluatedPropertyNames)
      var builder = ValidationResultBuilder(keyword: self, instanceLocation: instanceLocation)
      var validatedPropertyNames = Set<String>()

      for propertyName in unevaluatedPropertyNames {
        guard let propertyValue = instanceObject[propertyName] else { continue }
        var subAnnotations = AnnotationContainer()
        let propertyLocation = instanceLocation.appending(.key(propertyName))
        let result = subschema.validate(propertyValue, at: propertyLocation, annotations: &subAnnotations)
        builder.merging(result)
        annotations.merge(subAnnotations)
        validatedPropertyNames.insert(propertyName)
      }

      try builder.throwIfErrors()

      annotations.insert(keyword: self, at: instanceLocation, value: validatedPropertyNames)
    }
  }
}

// MARK: - Helpers

extension Never: AnnotationValueConvertible {
  var value: JSONValue { .null }

  func merged(with other: Never) -> Never {}
}

extension Set: AnnotationValueConvertible where Element == String {
  var value: JSONSchema.JSONValue {
    .array(self.map { .string($0) })
  }

  func merged(with other: Set<String>) -> Set<String> {
    self.union(other)
  }
}

extension Bool: AnnotationValueConvertible {
  var value: JSONValue { .boolean(self) }

  func merged(with other: Bool) -> Bool {
    self || other
  }
}

private extension Array where Element == JSONValue {
  func extractSubschemas(using context: KeywordContext) -> [Schema] {
    var subschemas = [Schema]()
    subschemas.reserveCapacity(self.count)
    for (index, rawSchema) in self.enumerated() {
      let pointer = context.location.appending(.index(index))
      if let subschema = try? Schema(rawSchema: rawSchema, location: pointer, context: context.context, baseURI: context.uri) {
        subschemas.append(subschema)
      }
    }
    return subschemas
  }
}

private extension JSONValue {
  func extractSubschema(using context: KeywordContext) -> Schema {
    (try? Schema(rawSchema: self, location: context.location, context: context.context, baseURI: context.uri)) ?? BooleanSchema(schemaValue: true, location: context.location, context: context.context).asSchema()
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
    if result.valid {

    } else {
      if let resultErrors = result.errors {
        errors.append(contentsOf: resultErrors)
      }
      else {
        errors.append(
          .init(
            keyword: type(of: keyword).name,
            message: "Validation failed",
            keywordLocation: keyword.context.location,
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
