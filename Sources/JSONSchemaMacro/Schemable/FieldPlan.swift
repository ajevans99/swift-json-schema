import SwiftSyntax
import SwiftSyntaxBuilder

struct FieldPlan {
  enum Base {
    case inferred(SchemaType)
    case custom(ExprSyntax)
  }

  let key: ExprSyntax
  let base: Base
  let defaultValue: ExprSyntax?
  let modifiers: [ParsedOption]
  let description: String?
  let nullStyle: ExprSyntax?
  let isRequired: Bool

  var usesSelfReference: Bool {
    if case .inferred(let type) = base { return type.usesSelfReference }
    return false
  }
}

enum FieldPlanner {
  static func plan(
    type: SchemaType,
    key: ExprSyntax,
    defaultValue: ExprSyntax?,
    docString: String?,
    options: [ParsedOption] = [],
    nullStyle: ExprSyntax? = nil
  ) -> FieldPlan {
    var base = FieldPlan.Base.inferred(type)
    var inferredDefault = type.isPrimitive ? defaultValue : nil
    var modifiers: [ParsedOption] = []
    for option in options {
      switch option.kind {
      case .customSchema(let value):
        // Replacement is ordered: modifiers before the custom schema are discarded.
        base = .custom(value)
        inferredDefault = nil
        modifiers.removeAll()
      case .key, .orNull:
        break
      case .modifier:
        modifiers.append(option)
      }
    }
    return FieldPlan(
      key: key,
      base: base,
      defaultValue: inferredDefault,
      modifiers: modifiers,
      description: options.contains { $0.name.text == "description" } ? nil : docString,
      nullStyle: type.isOptional ? nullStyle : nil,
      isRequired: !type.isOptional
    )
  }
}

enum FieldEmitter {
  static func codeBlock(
    for plan: FieldPlan,
    multilineDescription: Bool = false
  ) -> CodeBlockItemSyntax {
    var schema: CodeBlockItemSyntax
    switch plan.base {
    case .inferred(let type): schema = "\(TypeSchemaEmitter.expression(for: type))"
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
