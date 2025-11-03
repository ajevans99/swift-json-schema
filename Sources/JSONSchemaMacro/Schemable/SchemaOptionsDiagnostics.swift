import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Handles validation and diagnostics for @SchemaOptions and type-specific option macros
struct SchemaOptionsDiagnostics {
  let propertyName: TokenSyntax
  let propertyType: TypeSyntax
  let context: any MacroExpansionContext

  /// Validates SchemaOptions and emits diagnostics for invalid configurations
  func validateSchemaOptions(_ options: LabeledExprListSyntax) {
    // Check for conflicting readOnly/writeOnly
    validateReadWriteConflict(options)

    // Check for duplicate options
    validateNoDuplicates(options, macroName: "SchemaOptions")
  }

  /// Validates type-specific options (StringOptions, NumberOptions, etc.)
  func validateTypeSpecificOptions(_ options: LabeledExprListSyntax, macroName: String) {
    // 1. Check that the option macro matches the property type
    validateTypeCompatibility(macroName: macroName)

    // 2. Check for logical conflicts in constraints
    validateConstraintLogic(options, macroName: macroName)

    // 3. Check for invalid constraint values
    validateConstraintValues(options, macroName: macroName)

    // 4. Check for duplicate options
    validateNoDuplicates(options, macroName: macroName)
  }

  // MARK: - Type Compatibility

  private func validateTypeCompatibility(macroName: String) {
    let typeInfo = propertyType.typeInformation()

    switch macroName {
    case "StringOptions":
      guard case .primitive(.string, _) = typeInfo else {
        emitTypeMismatch(macroName: macroName, expectedType: "String", actualType: typeInfo)
        return
      }

    case "NumberOptions":
      switch typeInfo {
      case .primitive(.int, _), .primitive(.double, _):
        break  // Valid numeric types
      default:
        emitTypeMismatch(macroName: macroName, expectedType: "numeric (Int, Double, etc.)", actualType: typeInfo)
      }

    case "ArrayOptions":
      // Check if type is an array
      let typeString = propertyType.description.trimmingCharacters(in: .whitespaces)
      if !typeString.hasPrefix("[") && !typeString.contains("Array<") {
        let diagnostic = Diagnostic(
          node: propertyName,
          message: SchemaOptionsMismatchDiagnostic.typeMismatch(
            macroName: macroName,
            propertyName: propertyName.text,
            expectedType: "Array",
            actualType: typeString
          )
        )
        context.diagnose(diagnostic)
      }

    case "ObjectOptions":
      // ObjectOptions can be used on Dictionary or custom types (structs/classes)
      // We'll be permissive here since many types could be objects
      break

    default:
      break
    }
  }

  private func emitTypeMismatch(macroName: String, expectedType: String, actualType: TypeSyntax.TypeInformation) {
    let actualTypeString: String
    switch actualType {
    case .primitive(let primitive, _):
      actualTypeString = primitive.rawValue
    case .schemable(let name, _):
      actualTypeString = name
    case .notSupported:
      actualTypeString = propertyType.description.trimmingCharacters(in: .whitespaces)
    }

    let diagnostic = Diagnostic(
      node: propertyName,
      message: SchemaOptionsMismatchDiagnostic.typeMismatch(
        macroName: macroName,
        propertyName: propertyName.text,
        expectedType: expectedType,
        actualType: actualTypeString
      )
    )
    context.diagnose(diagnostic)
  }

  // MARK: - Constraint Logic Validation

  private func validateConstraintLogic(_ options: LabeledExprListSyntax, macroName: String) {
    let constraints = extractConstraints(from: options)

    switch macroName {
    case "StringOptions":
      validateMinMaxLogic(
        constraints: constraints,
        minKey: "minLength",
        maxKey: "maxLength",
        constraintType: "string length"
      )

    case "NumberOptions":
      validateMinMaxLogic(
        constraints: constraints,
        minKey: "minimum",
        maxKey: "maximum",
        constraintType: "value"
      )
      validateMinMaxLogic(
        constraints: constraints,
        minKey: "exclusiveMinimum",
        maxKey: "exclusiveMaximum",
        constraintType: "value"
      )

      // Check for conflicting minimum types
      if constraints["minimum"] != nil && constraints["exclusiveMinimum"] != nil {
        let diagnostic = Diagnostic(
          node: propertyName,
          message: SchemaOptionsMismatchDiagnostic.conflictingConstraints(
            propertyName: propertyName.text,
            constraint1: "minimum",
            constraint2: "exclusiveMinimum",
            suggestion: "Use only one of minimum or exclusiveMinimum"
          )
        )
        context.diagnose(diagnostic)
      }

      // Check for conflicting maximum types
      if constraints["maximum"] != nil && constraints["exclusiveMaximum"] != nil {
        let diagnostic = Diagnostic(
          node: propertyName,
          message: SchemaOptionsMismatchDiagnostic.conflictingConstraints(
            propertyName: propertyName.text,
            constraint1: "maximum",
            constraint2: "exclusiveMaximum",
            suggestion: "Use only one of maximum or exclusiveMaximum"
          )
        )
        context.diagnose(diagnostic)
      }

    case "ArrayOptions":
      validateMinMaxLogic(
        constraints: constraints,
        minKey: "minItems",
        maxKey: "maxItems",
        constraintType: "array size"
      )
      validateMinMaxLogic(
        constraints: constraints,
        minKey: "minContains",
        maxKey: "maxContains",
        constraintType: "contains count"
      )

    case "ObjectOptions":
      validateMinMaxLogic(
        constraints: constraints,
        minKey: "minProperties",
        maxKey: "maxProperties",
        constraintType: "property count"
      )

    default:
      break
    }
  }

  private func validateMinMaxLogic(
    constraints: [String: Double],
    minKey: String,
    maxKey: String,
    constraintType: String
  ) {
    guard let minValue = constraints[minKey],
          let maxValue = constraints[maxKey] else { return }

    if minValue > maxValue {
      let diagnostic = Diagnostic(
        node: propertyName,
        message: SchemaOptionsMismatchDiagnostic.minGreaterThanMax(
          propertyName: propertyName.text,
          minKey: minKey,
          minValue: minValue,
          maxKey: maxKey,
          maxValue: maxValue,
          constraintType: constraintType
        )
      )
      context.diagnose(diagnostic)
    }
  }

  // MARK: - Constraint Value Validation

  private func validateConstraintValues(_ options: LabeledExprListSyntax, macroName: String) {
    let constraints = extractConstraints(from: options)

    // Validate non-negative constraints
    let nonNegativeConstraints: [String]
    switch macroName {
    case "StringOptions":
      nonNegativeConstraints = ["minLength", "maxLength"]
    case "ArrayOptions":
      nonNegativeConstraints = ["minItems", "maxItems", "minContains", "maxContains"]
    case "ObjectOptions":
      nonNegativeConstraints = ["minProperties", "maxProperties"]
    case "NumberOptions":
      nonNegativeConstraints = ["multipleOf"]
    default:
      nonNegativeConstraints = []
    }

    for constraintName in nonNegativeConstraints {
      if let value = constraints[constraintName], value < 0 {
        let diagnostic = Diagnostic(
          node: propertyName,
          message: SchemaOptionsMismatchDiagnostic.negativeValue(
            propertyName: propertyName.text,
            constraintName: constraintName,
            value: value
          )
        )
        context.diagnose(diagnostic)
      }
    }
  }

  // MARK: - ReadOnly/WriteOnly Validation

  private func validateReadWriteConflict(_ options: LabeledExprListSyntax) {
    var hasReadOnly = false
    var hasWriteOnly = false

    for option in options {
      guard let functionCall = option.expression.as(FunctionCallExprSyntax.self),
            let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) else {
        continue
      }

      let optionName = memberAccess.declName.baseName.text

      if optionName == "readOnly" {
        if let boolValue = extractBoolValue(from: functionCall), boolValue {
          hasReadOnly = true
        }
      } else if optionName == "writeOnly" {
        if let boolValue = extractBoolValue(from: functionCall), boolValue {
          hasWriteOnly = true
        }
      }
    }

    if hasReadOnly && hasWriteOnly {
      let diagnostic = Diagnostic(
        node: propertyName,
        message: SchemaOptionsMismatchDiagnostic.readOnlyAndWriteOnly(
          propertyName: propertyName.text
        )
      )
      context.diagnose(diagnostic)
    }
  }

  // MARK: - Duplicate Detection

  private func validateNoDuplicates(_ options: LabeledExprListSyntax, macroName: String) {
    var seenOptions: [String: Int] = [:]

    for option in options {
      guard let functionCall = option.expression.as(FunctionCallExprSyntax.self),
            let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) else {
        continue
      }

      let optionName = memberAccess.declName.baseName.text
      seenOptions[optionName, default: 0] += 1
    }

    for (optionName, count) in seenOptions where count > 1 {
      let diagnostic = Diagnostic(
        node: propertyName,
        message: SchemaOptionsMismatchDiagnostic.duplicateOption(
          propertyName: propertyName.text,
          optionName: optionName,
          count: count
        )
      )
      context.diagnose(diagnostic)
    }
  }

  // MARK: - Helper Methods

  private func extractConstraints(from options: LabeledExprListSyntax) -> [String: Double] {
    var constraints: [String: Double] = [:]

    for option in options {
      guard let functionCall = option.expression.as(FunctionCallExprSyntax.self),
            let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) else {
        continue
      }

      let constraintName = memberAccess.declName.baseName.text

      // Extract numeric value from first argument
      if let firstArg = functionCall.arguments.first,
         let value = extractNumericValue(from: firstArg.expression) {
        constraints[constraintName] = value
      }
    }

    return constraints
  }

  private func extractNumericValue(from expr: ExprSyntax) -> Double? {
    // Try integer literal
    if let intLiteral = expr.as(IntegerLiteralExprSyntax.self),
       let value = Double(intLiteral.literal.text) {
      return value
    }

    // Try float literal
    if let floatLiteral = expr.as(FloatLiteralExprSyntax.self),
       let value = Double(floatLiteral.literal.text) {
      return value
    }

    // Try negative integer
    if let prefixExpr = expr.as(PrefixOperatorExprSyntax.self),
       prefixExpr.operator.text == "-",
       let intLiteral = prefixExpr.expression.as(IntegerLiteralExprSyntax.self),
       let value = Double(intLiteral.literal.text) {
      return -value
    }

    // Try negative float
    if let prefixExpr = expr.as(PrefixOperatorExprSyntax.self),
       prefixExpr.operator.text == "-",
       let floatLiteral = prefixExpr.expression.as(FloatLiteralExprSyntax.self),
       let value = Double(floatLiteral.literal.text) {
      return -value
    }

    return nil
  }

  private func extractBoolValue(from functionCall: FunctionCallExprSyntax) -> Bool? {
    guard let firstArg = functionCall.arguments.first else {
      // No argument means default true for some options
      return true
    }

    if let boolLiteral = firstArg.expression.as(BooleanLiteralExprSyntax.self) {
      return boolLiteral.literal.text == "true"
    }

    return nil
  }
}

/// Diagnostic messages for SchemaOptions mismatches
enum SchemaOptionsMismatchDiagnostic: DiagnosticMessage {
  case typeMismatch(macroName: String, propertyName: String, expectedType: String, actualType: String)
  case minGreaterThanMax(propertyName: String, minKey: String, minValue: Double, maxKey: String, maxValue: Double, constraintType: String)
  case negativeValue(propertyName: String, constraintName: String, value: Double)
  case readOnlyAndWriteOnly(propertyName: String)
  case conflictingConstraints(propertyName: String, constraint1: String, constraint2: String, suggestion: String)
  case duplicateOption(propertyName: String, optionName: String, count: Int)

  var message: String {
    switch self {
    case .typeMismatch(let macroName, let propertyName, let expectedType, let actualType):
      return """
        @\(macroName) can only be used on \(expectedType) properties, but '\(propertyName)' has type '\(actualType)'
        """

    case .minGreaterThanMax(let propertyName, let minKey, let minValue, let maxKey, let maxValue, let constraintType):
      let minFormatted = minValue.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(minValue)) : String(minValue)
      let maxFormatted = maxValue.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(maxValue)) : String(maxValue)
      return """
        Property '\(propertyName)' has \(minKey) (\(minFormatted)) greater than \(maxKey) (\(maxFormatted)). \
        This \(constraintType) constraint can never be satisfied.
        """

    case .negativeValue(let propertyName, let constraintName, let value):
      let valueFormatted = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
      return """
        Property '\(propertyName)' has \(constraintName) with negative value (\(valueFormatted)). \
        This constraint must be non-negative.
        """

    case .readOnlyAndWriteOnly(let propertyName):
      return """
        Property '\(propertyName)' cannot be both readOnly and writeOnly
        """

    case .conflictingConstraints(let propertyName, let constraint1, let constraint2, let suggestion):
      return """
        Property '\(propertyName)' has both \(constraint1) and \(constraint2) specified. \(suggestion).
        """

    case .duplicateOption(let propertyName, let optionName, let count):
      return """
        Property '\(propertyName)' has \(optionName) specified \(count) times. Only the last value will be used.
        """
    }
  }

  var diagnosticID: MessageID {
    switch self {
    case .typeMismatch:
      return MessageID(domain: "JSONSchemaMacro", id: "schemaOptionsTypeMismatch")
    case .minGreaterThanMax:
      return MessageID(domain: "JSONSchemaMacro", id: "schemaOptionsMinGreaterThanMax")
    case .negativeValue:
      return MessageID(domain: "JSONSchemaMacro", id: "schemaOptionsNegativeValue")
    case .readOnlyAndWriteOnly:
      return MessageID(domain: "JSONSchemaMacro", id: "schemaOptionsReadOnlyAndWriteOnly")
    case .conflictingConstraints:
      return MessageID(domain: "JSONSchemaMacro", id: "schemaOptionsConflictingConstraints")
    case .duplicateOption:
      return MessageID(domain: "JSONSchemaMacro", id: "schemaOptionsDuplicate")
    }
  }

  var severity: DiagnosticSeverity {
    switch self {
    case .typeMismatch, .minGreaterThanMax, .negativeValue, .readOnlyAndWriteOnly:
      return .error
    case .conflictingConstraints, .duplicateOption:
      return .warning
    }
  }
}
