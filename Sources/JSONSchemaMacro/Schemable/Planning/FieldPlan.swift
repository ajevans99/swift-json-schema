import SwiftSyntax

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
