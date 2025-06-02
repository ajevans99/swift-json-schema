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
        let codeBlock: CodeBlockItemSyntax

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
            label: label,
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
}
