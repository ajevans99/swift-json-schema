import SwiftDiagnostics
import SwiftSyntax

enum OptionAttribute: String, CaseIterable {
  case schema = "SchemaOptions"
  case number = "NumberOptions"
  case array = "ArrayOptions"
  case object = "ObjectOptions"
  case string = "StringOptions"
}

struct ParsedOption {
  enum Kind {
    case key(ExprSyntax)
    case orNull(ExprSyntax)
    case customSchema(ExprSyntax)
    case modifier
  }

  let source: ExprSyntax
  let call: FunctionCallExprSyntax
  let name: TokenSyntax
  let kind: Kind

  var arguments: LabeledExprListSyntax { call.arguments }
  var firstValue: ExprSyntax? { arguments.first?.expression }
  var trailingClosure: ClosureExprSyntax? { call.trailingClosure }

  init?(_ source: ExprSyntax) {
    guard let call = source.as(FunctionCallExprSyntax.self),
      let member = call.calledExpression.as(MemberAccessExprSyntax.self)
    else { return nil }

    self.source = source
    self.call = call
    name = member.declName.baseName
    switch name.text {
    case "key", "orNull", "customSchema":
      guard call.arguments.count == 1, let value = call.arguments.first?.expression else {
        return nil
      }
      switch name.text {
      case "key": kind = .key(value)
      case "orNull": kind = .orNull(value)
      default: kind = .customSchema(value)
      }
    default:
      kind = .modifier
    }
  }
}

struct ParsedOptions {
  struct Group {
    let attribute: OptionAttribute
    let options: [ParsedOption]
  }

  let groups: [Group]
  let diagnostics: [Diagnostic]

  init(attributes: AttributeListSyntax) {
    var groups: [Group] = []
    var diagnostics: [Diagnostic] = []
    for element in attributes {
      guard let attribute = element.as(AttributeSyntax.self),
        let name = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
        let kind = OptionAttribute(rawValue: name),
        let arguments = attribute.arguments?.as(LabeledExprListSyntax.self)
      else { continue }

      var options: [ParsedOption] = []
      for argument in arguments {
        if let option = ParsedOption(argument.expression) {
          options.append(option)
        } else {
          diagnostics.append(
            Diagnostic(node: argument.expression, message: OptionParsingDiagnostic())
          )
        }
      }
      groups.append(Group(attribute: kind, options: options))
    }
    self.groups = groups
    self.diagnostics = diagnostics
  }

  func options(for attributes: OptionAttribute...) -> [ParsedOption] {
    groups.filter { attributes.contains($0.attribute) }.flatMap(\.options)
  }

  var typeSpecific: [Group] { groups.filter { $0.attribute != .schema } }
}

private struct OptionParsingDiagnostic: DiagnosticMessage {
  var message: String {
    "Schema options must be direct option calls, such as .title(\"Title\")"
  }
  var diagnosticID: MessageID { MessageID(domain: "JSONSchemaMacro", id: "invalidOptionSyntax") }
  var severity: DiagnosticSeverity { .error }
}
