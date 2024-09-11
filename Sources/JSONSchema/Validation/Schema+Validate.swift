/// A protocol that all schema types will conform to.
/// It defines a method for validating a JSON instance.
public protocol JSONSchemaValidatable: Codable, Sendable {
  /// Validates the given JSON instance against the schema.
  ///
  /// - Parameter instance: The JSON value to validate.
  /// - Returns: An array of `ValidationIssues` if there are any validation errors, or `nil` if validation succeeds.
  func validate(_ instance: JSONValue) -> [ValidationIssue]?
}

extension RootSchema {
  public func validate(_ instance: JSONValue) -> [ValidationIssue]? {
    subschema?.validate(instance)
  }
}

extension Schema {
  public func validate(_ instance: JSONValue) -> [ValidationIssue]? {
    var builder = ValidationBuilder()

    // Validate type
    if let type {
      switch type {
      case .single(let primative):
        if instance.type != primative {
          builder.addIssue(.typeMismatch(expected: type, actual: instance.type))
        }
      case .array(let primatives):
        if !primatives.contains(instance.type) {
          builder.addIssue(.typeMismatch(expected: type, actual: instance.type))
        }
      }
    }

    // Validate enum values
    if let enumValues, !enumValues.contains(instance) {
        builder.addIssue(.enumMismatch(expected: enumValues, actual: instance))
    }

    // Validate composition
    if let composition = self.composition {
      validateComposition(composition, instance: instance, builder: &builder)
    }

    // Validate const value
    if let const, instance != const {
        builder.addIssue(.constMismatch(expected: const, actual: instance))
    }

    if let options {
      switch instance {
      case .string(let string):
        if let options = options.asType(StringSchemaOptions.self) {
          validateString(string, options: options, builder: &builder)
        } else if let dynamicOptions = options.asType(DynamicSchemaOptions.self), let options = dynamicOptions.string {
          validateString(string, options: options, builder: &builder)
        }
      case .number(let double):
        if let options = options.asType(NumberSchemaOptions.self) {
          validateNumber(double, options: options, builder: &builder)
        } else if let dynamicOptions = options.asType(DynamicSchemaOptions.self), let options = dynamicOptions.number {
          validateNumber(double, options: options, builder: &builder)
        }
      case .integer(let int):
        if let options = options.asType(NumberSchemaOptions.self) {
          validateInteger(int, options: options, builder: &builder)
        } else if let dynamicOptions = options.asType(DynamicSchemaOptions.self), let options = dynamicOptions.number {
          validateInteger(int, options: options, builder: &builder)
        }
      case .object(let dictionary):
        if let options = options.asType(ObjectSchemaOptions.self) {
          validateObject(dictionary, options: options, builder: &builder)
        } else if let dynamicOptions = options.asType(DynamicSchemaOptions.self), let options = dynamicOptions.object {
          validateObject(dictionary, options: options, builder: &builder)
        }
      case .array(let array):
        if let options = options.asType(ArraySchemaOptions.self) {
          validateArray(array, options: options, builder: &builder)
        } else if let dynamicOptions = options.asType(DynamicSchemaOptions.self), let options = dynamicOptions.array {
          validateArray(array, options: options, builder: &builder)
        }
      case .boolean, .null:
        break
      }
    }

    return builder.issues.isEmpty ? nil : builder.issues
  }
}

struct ValidationBuilder {
  var issues = [ValidationIssue]()

  mutating func addIssue(_ issue: ValidationIssue) {
    self.issues.append(issue)
  }

  mutating func addIssues(_ issues: [ValidationIssue]) {
    self.issues.append(contentsOf: issues)
  }
}

private extension Schema {
  private func validateComposition(_ composition: CompositionOptions, instance: JSONValue, builder: inout ValidationBuilder) {
    switch composition {
    case .allOf(let schemas):
      var allOfBuilder = ValidationBuilder()
      for schema in schemas {
        if let issues = schema.validate(instance) {
          allOfBuilder.addIssues(issues)
        }
      }
      if !allOfBuilder.issues.isEmpty {
        builder.addIssue(.composition(issue: .allOf(violations: allOfBuilder.issues), actual: instance))
      }
    case .anyOf(let schemas):
      var anyOfBuilder = ValidationBuilder()
      var didValidateAny = false
      for schema in schemas {
        if let issues = schema.validate(instance) {
          anyOfBuilder.addIssues(issues)
        } else {
          didValidateAny = true
          break
        }
      }
      if !didValidateAny {
        builder.addIssue(.composition(issue: .anyOf(violations: anyOfBuilder.issues), actual: instance))
      }
    case .oneOf(let schemas):
      var oneOfBuilder = ValidationBuilder()
      var validCount = 0
      for schema in schemas {
        if let issues = schema.validate(instance) {
          oneOfBuilder.addIssues(issues)
        } else {
          validCount += 1
        }
      }
      if validCount != 1 {
        builder.addIssue(.composition(issue: .oneOf(violations: oneOfBuilder.issues), actual: instance))
      }
    case .not(let schema):
      if schema.validate(instance) == nil {
        builder.addIssue(.composition(issue: .not, actual: instance))
      }
    }
  }

  func validateString(_ value: String, options: StringSchemaOptions, builder: inout ValidationBuilder) {
    // Validate minLength
    if let minLength = options.minLength, value.count < minLength {
      builder.addIssue(.string(issue: .minLength(expected: minLength), actual: value))
    }

    // Validate maxLength
    if let maxLength = options.maxLength, value.count > maxLength {
      builder.addIssue(.string(issue: .maxLength(expected: maxLength), actual: value))
    }

    // Validate pattern
    if let pattern = options.pattern {
      do {
        let regex = try Regex(pattern)
        if value.wholeMatch(of: regex) == nil {
          builder.addIssue(.string(issue: .pattern(expected: pattern), actual: value))
        }
      } catch {
        builder.addIssue(.string(issue: .invalidRegularExpression, actual: value))
      }
    }

    // Note: Format validation is not implemented here, as it typically requires additional logic
    // specific to each format type (e.g., date-time, email, etc.)
    if options.format != nil {
      // You may want to add a comment or a placeholder for future implementation
      // builder.addIssue(.temporary("Format validation not implemented"))
    }
  }

  func validateNumber(_ value: Double, options: NumberSchemaOptions, builder: inout ValidationBuilder) {
    // Validate minimum
    if let minimum = options.minimum {
      switch minimum {
      case .exclusive(let minValue):
        if value <= minValue {
          builder.addIssue(.number(issue: .minimum(isInclusive: false, expected: minValue), actual: value))
        }
      case .inclusive(let minValue):
        if value < minValue {
          builder.addIssue(.number(issue: .minimum(isInclusive: true, expected: minValue), actual: value))
        }
      }
    }

    // Validate maximum
    if let maximum = options.maximum {
      switch maximum {
      case .exclusive(let maxValue):
        if value >= maxValue {
          builder.addIssue(.number(issue: .maximum(isInclusive: false, expected: maxValue), actual: value))
        }
      case .inclusive(let maxValue):
        if value > maxValue {
          builder.addIssue(.number(issue: .maximum(isInclusive: true, expected: maxValue), actual: value))
        }
      }
    }

    // Validate multipleOf
    if let multipleOf = options.multipleOf {
      let remainder = value.truncatingRemainder(dividingBy: multipleOf)
      if abs(remainder) > Double.ulpOfOne {
        builder.addIssue(.number(issue: .multipleOf(expected: multipleOf), actual: value))
      }
    }
  }

  func validateInteger(_ value: Int, options: NumberSchemaOptions, builder: inout ValidationBuilder) {
    // Validate minimum
    if let minimum = options.minimum {
      switch minimum {
      case .exclusive(let minValue):
        if Double(value) <= minValue {
          builder.addIssue(.integer(issue: .minimum(isInclusive: false, expected: minValue), actual: value))
        }
      case .inclusive(let minValue):
        if Double(value) < minValue {
          builder.addIssue(.integer(issue: .minimum(isInclusive: true, expected: minValue), actual: value))
        }
      }
    }

    // Validate maximum
    if let maximum = options.maximum {
      switch maximum {
      case .exclusive(let maxValue):
        if Double(value) >= maxValue {
          builder.addIssue(.integer(issue: .maximum(isInclusive: false, expected: maxValue), actual: value))
        }
      case .inclusive(let maxValue):
        if Double(value) > maxValue {
          builder.addIssue(.integer(issue: .maximum(isInclusive: true, expected: maxValue), actual: value))
        }
      }
    }

    // Validate multipleOf
    if let multipleOf = options.multipleOf {
      if value % Int(multipleOf) != 0 {
        builder.addIssue(.integer(issue: .multipleOf(expected: multipleOf), actual: value))
      }
    }
  }

  func validateObject(_ value: [String: JSONValue], options: ObjectSchemaOptions, builder: inout ValidationBuilder) {
    // Validate required properties
    if let required = options.required {
      for key in required {
        if value[key] == nil {
          builder.addIssue(.object(issue: .required(key: key), actual: value))
        }
      }
    }

    // Validate minProperties
    if let minProperties = options.minProperties, value.count < minProperties {
      builder.addIssue(.object(issue: .minProperties(expected: minProperties), actual: value))
    }

    // Validate maxProperties
    if let maxProperties = options.maxProperties, value.count > maxProperties {
      builder.addIssue(.object(issue: .maxProperties(expected: maxProperties), actual: value))
    }

    // Validate properties
    if let properties = options.properties {
      for (key, schema) in properties {
        if let propertyValue = value[key], let issues = schema.validate(propertyValue) {
          builder.addIssues(issues)
        }
      }
    }

    // Validate patternProperties
    if let patternProperties = options.patternProperties {
      for (pattern, schema) in patternProperties {
        do {
          let regex = try Regex(pattern)
          for (key, propertyValue) in value where key.wholeMatch(of: regex) != nil {
            if let issues = schema.validate(propertyValue) {
              builder.addIssues(issues)
            }
          }
        } catch {
          builder.addIssue(.string(issue: .invalidRegularExpression, actual: pattern))
        }
      }
    }

    // Validate propertyNames
    if let propertyNames = options.propertyNames {
      let schema = Schema.string(.annotations(), propertyNames)
      for key in value.keys {
        if let issues = schema.validate(.string(key)) {
          builder.addIssue(.object(issue: .propertyNames(key: key, issues: issues), actual: value))
        }
      }
    }

    // Validate additionalProperties
    if let additionalProperties = options.additionalProperties {
      
    }
  }

  func validateArray(_ value: [JSONValue], options: ArraySchemaOptions, builder: inout ValidationBuilder) {
    // Validate minItems
    if let minItems = options.minItems, value.count < minItems {
      builder.addIssue(.array(issue: .minItems(expected: minItems), actual: value))
    }

    // Validate maxItems
    if let maxItems = options.maxItems, value.count > maxItems {
      builder.addIssue(.array(issue: .maxItems(expected: maxItems), actual: value))
    }

    // Validate uniqueItems
    if options.uniqueItems == true {
      var seenItems = Set<JSONValue>()
      for item in value {
        if !seenItems.insert(item).inserted {
          builder.addIssue(.array(issue: .uniqueItems(duplicate: item), actual: value))
        }
      }
    }

    // Validate items
    if let items = options.items, case .schema(let schema) = items {
      for item in value {
        if let issues = schema.validate(item) {
          builder.addIssues(issues)
        }
      }
    }

    // Validate prefixItems
    if let prefixItems = options.prefixItems {
      for (index, schema) in prefixItems.enumerated() where index < value.count {
        if let issues = schema.validate(value[index]) {
          builder.addIssues(issues)
        }
      }
    }

    // Validate contains
    if let contains = options.contains {
      var matchCount = 0
      for item in value {
        if contains.validate(item) == nil {
          matchCount += 1
        }
      }
      if let minContains = options.minContains, matchCount < minContains {
        builder.addIssue(.array(issue: .minContains(expected: minContains), actual: value))
      }
      if let maxContains = options.maxContains, matchCount > maxContains {
        builder.addIssue(.array(issue: .maxContains(expected: maxContains), actual: value))
      }
    }
  }
}
