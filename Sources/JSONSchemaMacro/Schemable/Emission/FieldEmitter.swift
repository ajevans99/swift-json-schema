import SwiftSyntax
import SwiftSyntaxBuilder

enum FieldEmitter {
  static func codeBlock(
    for plan: FieldPlan,
    multilineDescription: Bool = false
  ) -> CodeBlockItemSyntax {
    var schema: CodeBlockItemSyntax
    switch plan.base {
    case .inferred(let type):
      schema = "\(TypeSchemaEmitter.expression(for: type, inlineNamedTypes: plan.inlineNamedTypes))"
    case .custom(let value): schema = "\(value).schema"
    }
    if let defaultValue = plan.defaultValue {
      schema = """
        \(schema)
        .default(\(defaultValue.trimmed))
        """
    }
    schema = SchemaOptionsGenerator.apply(plan.modifiers, to: schema)
    if let description = plan.description {
      let literal: ExprSyntax
      if multilineDescription {
        var pounds = "#"
        while description.contains("\"\"\"\(pounds)") || description.contains("\\\(pounds)") {
          pounds.append("#")
        }
        literal = """
          \(raw: pounds)\"\"\"
          \(raw: description)
          \"\"\"\(raw: pounds)
          """
      } else {
        literal = "\(literal: description)"
      }
      schema = """
        \(schema)
        .description(\(literal))
        """
    }
    if let style = plan.nullStyle {
      schema = """
        \(schema)
        .orNull(style: \(style))
        """
    }
    var field: CodeBlockItemSyntax = """
      JSONProperty(key: \(plan.key)) { \(schema) }
      """
    if plan.nullStyle != nil {
      field = """
        \(field)
        .flatMapOptional()
        """
    }
    if plan.isRequired {
      field = """
        \(field)
        .required()
        """
    }
    return field
  }
}
