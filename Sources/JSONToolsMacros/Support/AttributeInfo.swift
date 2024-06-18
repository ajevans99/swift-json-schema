import SwiftSyntax
import SwiftSyntaxMacros

/// A type describing information parsed from a `@ToolParameter` attribute.
struct AttributeInfo {
  /// The attribute node that was parsed to produce this instance.
  var attribute: AttributeSyntax

  /// The display name of the attribute, if present.
  var description: StringLiteralExprSyntax?

  init(byParsing attribute: AttributeSyntax) {
    self.attribute = attribute

    if let arguments = attribute.arguments, case .argumentList(let argumentList) = arguments {
      // If the first argument is an unlabelled string literal, it's the description of the tool.
      if let firstArgument = argumentList.first {
        let firstArgumentHasLabel = (firstArgument.label != nil)
        if !firstArgumentHasLabel,
          let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self)
        {
          description = stringLiteral
        }
      }
    }
  }
}
