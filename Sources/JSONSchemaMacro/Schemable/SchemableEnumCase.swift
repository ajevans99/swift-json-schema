import SwiftSyntax

struct SchemableEnumCase {
  let identifier: TokenSyntax
  let associatedValues: EnumCaseParameterListSyntax?

  init(enumCaseDecl: EnumCaseDeclSyntax, caseElement: EnumCaseElementSyntax) {
    identifier = caseElement.name.trimmed
    associatedValues = caseElement.parameterClause?.parameters
  }

  func generateSchema() -> CodeBlockItemSyntax? {
    guard let associatedValues else {
      return """
        "\(identifier)"
        """
    }
    let properties: [CodeBlockItemSyntax] = associatedValues.enumerated()
      .compactMap { index, parameter in
        let key = parameter.firstName?.text ?? "_\(index)"

        let typeInfo = parameter.type.typeInformation()
        var codeBlock: CodeBlockItemSyntax

        switch typeInfo {
        case .primitive(_, schema: let code):
          if let defaultValue = parameter.defaultValue?.value {
            codeBlock = """
              \(code)
              .default(\(defaultValue))
              """
          } else {
            codeBlock = code
          }
        case .schemable(_, schema: let code): codeBlock = code
        case .notSupported: return nil
        }

        // Add description if available
        if let docString = parameter.docString {
          codeBlock = """
            \(codeBlock)
            .description(\(literal: docString))
            """
        }

        var block: CodeBlockItemSyntax = """
          JSONProperty(key: "\(raw: key)") { \(codeBlock) }
          """

        if !parameter.type.isOptional {
          block = """
            \(block)
            .required()
            """
        }

        return block
      }

    let mapExpressionList = LabeledExprListSyntax {
      for (index, parameter) in associatedValues.enumerated() {
        if let label = parameter.firstName, label.text != "_" {
          LabeledExprSyntax(
            label: label.trimmed,
            colon: .colonToken(trailingTrivia: .space),
            expression: DeclReferenceExprSyntax(baseName: "$\(raw: index)")
          )
        } else {
          LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: "$\(raw: index)"))
        }
      }
    }

    let list = CodeBlockItemListSyntax(properties)

    let property: CodeBlockItemSyntax = """
      JSONProperty(key: "\(raw: identifier.text)") { JSONObject { \(list) } }
      .required()
      """

    return """
      JSONObject { \(property) }
      .map {
        Self.\(identifier)(\(mapExpressionList))
      }
      """
  }

  func generateEncodingCase(enumName: TokenSyntax) -> SwitchCaseSyntax? {
    guard let associatedValues else {
      return """
        case .\(identifier):
          return JSONValue.string("\(raw: identifier.text)")
        """
    }

    var bindingNames: [TokenSyntax] = []
    var payloadStatements: [String] = []

    for (index, parameter) in associatedValues.enumerated() {
      let bindingName: TokenSyntax
      if let secondName = parameter.secondName?.trimmed {
        bindingName = secondName
      } else if let firstName = parameter.firstName?.trimmed, firstName.text != "_" {
        bindingName = firstName
      } else {
        bindingName = .identifier("value\(index)")
      }
      bindingNames.append(bindingName)

      let key = parameter.firstName?.text ?? "_\(index)"
      let context = "\(enumName.text).\(identifier.text).\(key)"

      if let wrapped = parameter.type.unwrappedOptionalType() {
        let optionalName = "value\(index)Optional"
        guard
          let encodedExpr = wrapped.encodeExpression(
            valueExpr: identifierExpr(optionalName),
            customSchema: nil,
            context: context
          )
        else { return nil }
        let encodedSource = encodedExpr.description
        payloadStatements.append(
          """
            if let \(optionalName) = \(identifierText(for: bindingName)) {
              payload["\(key)"] = \(encodedSource)
            }
          """
        )
      } else {
        guard
          let encodedExpr = parameter.type.encodeExpression(
            valueExpr: ExprSyntax(DeclReferenceExprSyntax(baseName: bindingName)),
            customSchema: nil,
            context: context
          )
        else { return nil }
        let encodedSource = encodedExpr.description
        payloadStatements.append(
          """
            payload["\(key)"] = \(encodedSource)
          """
        )
      }
    }

    let patternBindings = bindingNames.map { "let \(identifierText(for: $0))" }.joined(separator: ", ")
    var source = "      case .\(identifier)(\(patternBindings)):\n"
    source += "        var payload: [String: JSONValue] = [:]\n"
    for statement in payloadStatements {
      source += "\(statement)\n"
    }
    source += "        return JSONValue.object([\n"
    source += "          \"\(identifier.text)\": .object(payload)\n"
    source += "        ])"

    return SwitchCaseSyntax(stringLiteral: source)
  }

  private func identifierText(for token: TokenSyntax) -> String {
    switch token.tokenKind {
    case .identifier(let text):
      if isValidIdentifier(text) { return text }
    default:
      break
    }
    return "`\(token.text)`"
  }

  private func isValidIdentifier(_ text: String) -> Bool {
    guard let first = text.first, first.isLetter || first == "_" else { return false }
    return text.dropFirst().allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }
}
