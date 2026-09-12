import SwiftSyntax
import SwiftSyntaxBuilder

enum SchemaOptionsGenerator {
  static func apply(
    _ options: [ParsedOption],
    to expression: CodeBlockItemSyntax
  ) -> CodeBlockItemSyntax {
    options.reduce(expression) { expression, option in
      switch option.kind {
      case .key:
        return expression
      case .customSchema(let value):
        return "\(value).schema"
      case .orNull, .modifier:
        if let closure = option.trailingClosure {
          return applyClosure(option, closure: closure, to: expression)
        }
        return """
          \(expression)
          .\(option.name.trimmed)(\(option.arguments))
          """
      }
    }
  }

  private static func applyClosure(
    _ option: ParsedOption,
    closure: ClosureExprSyntax,
    to expression: CodeBlockItemSyntax
  ) -> CodeBlockItemSyntax {
    if option.name.text == "additionalProperties",
      closure.signature == nil, closure.statements.count == 1,
      let first = closure.statements.first,
      let value = first.item.as(BooleanLiteralExprSyntax.self)
    {
      return """
        \(expression)
        .additionalProperties(\(value.trimmed))
        """
    }

    let arguments: String = option.arguments.isEmpty ? "" : "(\(option.arguments))"
    let result: CodeBlockItemSyntax
    if closure.signature == nil {
      result = """
        \(expression)
        .\(option.name.trimmed)\(raw: arguments) { \(closure.statements) }\(option.call.additionalTrailingClosures)
        """
    } else {
      result = """
        \(expression)
        .\(option.name.trimmed)\(raw: arguments) \(closure.trimmed)\(option.call.additionalTrailingClosures)
        """
    }
    switch option.name.text {
    case "additionalProperties", "patternProperties", "propertyNames":
      return """
        \(result)
        // Drop the parse information. Use custom builder if needed.
        .map { $0.0 }
        """
    default:
      return result
    }
  }
}
