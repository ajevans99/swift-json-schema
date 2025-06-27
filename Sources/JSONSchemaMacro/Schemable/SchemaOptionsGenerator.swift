import SwiftSyntax

enum SchemaOptionsGenerator {
  static func apply(
    _ arguments: LabeledExprListSyntax,
    to codeBlockItem: CodeBlockItemSyntax,
    for type: String
  ) -> CodeBlockItemSyntax {
    var result = codeBlockItem

    for argument in arguments {
      result = applyOption(argument, to: result)
    }

    return result
  }

  private static func applyOption(
    _ argument: LabeledExprSyntax,
    to codeBlockItem: CodeBlockItemSyntax
  ) -> CodeBlockItemSyntax {
    guard let functionCall = argument.expression.as(FunctionCallExprSyntax.self),
      let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self)
    else {
      return codeBlockItem
    }

    let optionName = memberAccess.declName.baseName.text

    if optionName == "key" {
      return codeBlockItem
    }

    // Handle customSchema specially - it replaces the entire schema
    if optionName == "customSchema" {
      guard let value = functionCall.arguments.first else {
        return codeBlockItem
      }

      return "\(value).schema"
    }

    if let closure = functionCall.trailingClosure {
      return applyClosureBasedOption(optionName, closure: closure, to: codeBlockItem)
    } else if let value = functionCall.arguments.first {
      return """
        \(codeBlockItem)
        .\(raw: optionName)(\(value))
        """
    }

    return codeBlockItem
  }

  private static func applyClosureBasedOption(
    _ optionName: String,
    closure: ClosureExprSyntax,
    to codeBlockItem: CodeBlockItemSyntax
  ) -> CodeBlockItemSyntax {
    switch optionName {
    case "additionalProperties":
      if closure.statements.count == 1,
        let first = closure.statements.first,
        let expr = first.item.as(ExprSyntax.self),
        let bool = expr.as(BooleanLiteralExprSyntax.self)
      {
        return """
          \(codeBlockItem)
          .additionalProperties(\(raw: bool.literal.text))
          """
      }
      // Intentionally fall through to "patternProperties" to handle shared logic.
      fallthrough
    case "patternProperties":
      return """
        \(codeBlockItem)
        .\(raw: optionName) { \(closure.statements) }
        // Drop the parse information. Use custom builder if needed.
        .map { $0.0 }
        """
    default:
      return """
        \(codeBlockItem)
        .\(raw: optionName) { \(closure.statements) }
        """
    }
  }
}
