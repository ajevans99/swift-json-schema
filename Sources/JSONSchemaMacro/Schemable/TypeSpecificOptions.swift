import SwiftSyntax

enum TypeSpecificOptions {
  static func apply(
    _ arguments: LabeledExprListSyntax,
    to codeBlockItem: CodeBlockItemSyntax,
    for type: TypeSyntax
  ) -> CodeBlockItemSyntax {
    var result = codeBlockItem
    
    // Apply type-specific options for all types
    for argument in arguments {
      result = applyOption(argument, to: result, for: type)
    }
    
    return result
  }

  private static func applyOption(
    _ argument: LabeledExprSyntax,
    to codeBlockItem: CodeBlockItemSyntax,
    for type: TypeSyntax
  ) -> CodeBlockItemSyntax {
    guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
          let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) else {
      return codeBlockItem
    }

    let optionName = memberAccess.declName.baseName.text

    if let closure = functionCall.trailingClosure {
      return applyClosureBasedOption(optionName, closure: closure, to: codeBlockItem, for: type)
    } else {
      return applyValueBasedOption(optionName, functionCall: functionCall, to: codeBlockItem, for: type)
    }
  }

  private static func applyClosureBasedOption(
    _ optionName: String,
    closure: ClosureExprSyntax,
    to codeBlockItem: CodeBlockItemSyntax,
    for type: TypeSyntax
  ) -> CodeBlockItemSyntax {
    switch optionName {
    case "additionalProperties":
      return """
        \(codeBlockItem)
        .additionalProperties { \(closure.statements) }
        // Drop the `AdditionalPropertiesParseResult` parse information. Use custom builder if needed.
        .map { $0.0 }
        """
    case "patternProperties":
      return """
        \(codeBlockItem)
        .patternProperties { \(closure.statements) }
        // Drop the `PatternPropertiesParseResult` parse information. Use custom builder if needed.
        .map { $0.0 }
        """
    case "unevaluatedProperties":
      return """
        \(codeBlockItem)
        .unevaluatedProperties { \(closure.statements) }
        """
    case "propertyNames":
      return """
        \(codeBlockItem)
        .propertyNames { \(closure.statements) }
        """
    case "prefixItems":
      return """
        \(codeBlockItem)
        .prefixItems { \(closure.statements) }
        """
    case "unevaluatedItems":
      return """
        \(codeBlockItem)
        .unevaluatedItems { \(closure.statements) }
        """
    case "contains":
      return """
        \(codeBlockItem)
        .contains { \(closure.statements) }
        """
    default:
      return codeBlockItem
    }
  }

  private static func applyValueBasedOption(
    _ optionName: String,
    functionCall: FunctionCallExprSyntax,
    to codeBlockItem: CodeBlockItemSyntax,
    for type: TypeSyntax
  ) -> CodeBlockItemSyntax {
    guard let value = functionCall.arguments.first else {
      return codeBlockItem
    }

    switch optionName {
    case "minProperties":
      return """
        \(codeBlockItem)
        .minProperties(\(value))
        """
    case "maxProperties":
      return """
        \(codeBlockItem)
        .maxProperties(\(value))
        """
    case "minLength":
      return """
        \(codeBlockItem)
        .minLength(\(value))
        """
    case "maxLength":
      return """
        \(codeBlockItem)
        .maxLength(\(value))
        """
    case "pattern":
      return """
        \(codeBlockItem)
        .pattern(\(value))
        """
    case "format":
      return """
        \(codeBlockItem)
        .format(\(value))
        """
    case "multipleOf":
      return """
        \(codeBlockItem)
        .multipleOf(\(value))
        """
    case "minimum":
      return """
        \(codeBlockItem)
        .minimum(\(value))
        """
    case "exclusiveMinimum":
      return """
        \(codeBlockItem)
        .exclusiveMinimum(\(value))
        """
    case "maximum":
      return """
        \(codeBlockItem)
        .maximum(\(value))
        """
    case "exclusiveMaximum":
      return """
        \(codeBlockItem)
        .exclusiveMaximum(\(value))
        """
    case "minContains":
      return """
        \(codeBlockItem)
        .minContains(\(value))
        """
    case "maxContains":
      return """
        \(codeBlockItem)
        .maxContains(\(value))
        """
    case "minItems":
      return """
        \(codeBlockItem)
        .minItems(\(value))
        """
    case "maxItems":
      return """
        \(codeBlockItem)
        .maxItems(\(value))
        """
    case "uniqueItems":
      return """
        \(codeBlockItem)
        .uniqueItems(\(value))
        """
    default:
      return codeBlockItem
    }
  }
} 